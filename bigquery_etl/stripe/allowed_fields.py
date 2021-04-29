"""Limit imported Stripe data to a set of allowed fields."""

import re
from hashlib import sha256
from pathlib import Path
from typing import Any, Generator, Iterable, List, Type

import click
import stripe
import ujson
import yaml
from google.cloud import bigquery
from stripe.api_resources.abstract import ListableAPIResource


def _snake_case(resource: Type[ListableAPIResource]) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", resource.__name__).lower()


# event data types with separate events and a defined schema
ALLOWED_FIELDS = yaml.load((Path(__file__).parent / "allowed_fields.yaml").read_text())


def _valid_float(value: str):
    try:
        float(value)
    except ValueError:
        return False
    else:
        return True


class FilteredSchema:
    """Apply ALLOWED_FIELDS to resources and their schema."""

    type: str
    allowed: dict
    root: bigquery.SchemaField
    filtered: List[bigquery.SchemaField]

    def __init__(self, resource: Type[ListableAPIResource]):
        """Get filtered schema and allowed fields for a Stripe resource type."""
        self.type = _snake_case(resource)
        self.allowed = ALLOWED_FIELDS[self.type]
        path = Path(__file__).parent / f"{self.type}.schema.json"
        self.root = bigquery.SchemaField.from_api_repr(
            {"name": "root", "type": "RECORD", "fields": ujson.loads(path.read_text())}
        )
        self.filtered = list(self._filter_schema(self.root.fields, self.allowed))

    def _filter_schema(
        self, fields: List[bigquery.SchemaField], allowed: dict
    ) -> Iterable[bigquery.SchemaField]:
        for field in fields:
            if field.name not in allowed:
                continue
            if field.field_type != "RECORD":
                yield field
            else:
                yield bigquery.SchemaField.from_api_repr(
                    {
                        **field.to_api_repr(),
                        fields: list(
                            self._filter_schema(field.fields, allowed[field.name])
                        ),
                    }
                )

    def format_row(self, row: dict) -> bytes:
        """Format stripe object for BigQuery, and validate against original schema."""
        return ujson.dumps(
            self._format_helper(
                self.type, obj=row, allowed=self.allowed, field=self.root
            )
        ).encode("UTF-8")

    def _format_helper(
        self,
        *path,
        obj: Any,
        allowed: dict,
        field: bigquery.SchemaField,
        is_list_item: bool = False,
    ) -> Any:
        # override obj for metadata and paged lists
        if (
            field.name in ("metadata", "custom_fields")
            and isinstance(obj, dict)
            and not is_list_item
        ):
            if "userid" in obj:
                # hash fxa uid before it reaches BigQuery
                obj["fxa_uid"] = sha256(obj.pop("userid").encode("UTF-8")).hexdigest()
            # format metadata as a key-value list
            obj = [{"key": key, "value": value} for key, value in obj.items()]
        elif isinstance(obj, stripe.ListObject):
            if obj.data and _snake_case(type(obj.data[0])) in ALLOWED_FIELDS:
                # don't expand lists of resources that get updated in separate events
                return []
            # expand paged list
            obj = obj.auto_paging_iter()

        if isinstance(obj, (list, Generator)):
            # enforce schema
            if field.mode != "REPEATED":
                raise click.ClickException(
                    f"expected {field.field_type} at {'.'.join(path)} but got ARRAY"
                )
            return [
                self._format_helper(
                    *path[:-1],
                    f"{field.name}[{i}]",
                    obj=e,
                    allowed=allowed,
                    field=field,
                    is_list_item=True,
                )
                for i, e in enumerate(obj)
            ]
        if isinstance(obj, dict):
            # enforce schema
            if field.mode == "REPEATED" and not is_list_item:
                raise click.ClickException(
                    f"expected ARRAY at {'.'.join(path)} but got RECORD"
                )
            if field.field_type != "RECORD":
                raise click.ClickException(
                    f"expected {field.field_type} at {'.'.join(path)} but got RECORD"
                )
            # recursively format and keep allowed non-empty values
            fields_by_name = {f.name: f for f in field.fields}
            result = {}
            for key, value in obj.items():
                if key == "use_stripe_sdk":
                    # drop use_stripe_sdk because the contents are only for use in Stripe.js
                    # https://stripe.com/docs/api/payment_intents/object#payment_intent_object-next_action-use_stripe_sdk
                    continue
                if key not in fields_by_name:
                    # enforce schema
                    raise click.ClickException(
                        f"{'.'.join(path)} contained unexpected field: {key}"
                    )
                formatted = self._format_helper(
                    *path,
                    key,
                    obj=value,
                    allowed=allowed.get(key) or {},
                    field=fields_by_name[key],
                )
                # apply allow list after formatting to enforce schema
                if formatted not in (None, [], {}) and key in allowed:
                    result[key] = formatted
            return result
        # enforce schema
        if field.mode == "REPEATED" and not is_list_item:
            raise click.ClickException(
                f"expected ARRAY at {'.'.join(path)} but got {obj!r}"
            )
        if field.field_type == "RECORD" and obj is not None:
            raise click.ClickException(
                f"expected RECORD at {'.'.join(path)} but got {obj!r}"
            )
        if not (
            # None is valid for all types
            obj is None
            # STRING can be any primitive type
            or field.field_type == "STRING"
            # TIMESTAMP can be int or string
            or (field.field_type == "TIMESTAMP" and isinstance(obj, (int, str)))
            # INT64 can be int or digit string
            or (
                field.field_type in ("INT64", "INTEGER")
                and (isinstance(obj, int) or (isinstance(obj, str) and obj.isdecimal()))
            )
            # FLOAT64 can be int, float or decimal string
            or (
                field.field_type in ("FLOAT64", "FLOAT", "NUMERIC")
                and (
                    isinstance(obj, (int, float))
                    or (isinstance(obj, str) and _valid_float(obj))
                )
            )
            # BOOL must be bool
            or (field.field_type in ("BOOL", "BOOLEAN") and isinstance(obj, bool))
        ):
            raise click.ClickException(
                f"expected {field.field_type} at {'.'.join(path)} but got {obj!r}"
            )
        return obj
