
import ontoweaver

class urls_to_prop(ontoweaver.base.Transformer):

    class ValueMaker(ontoweaver.make_value.ValueMaker):
        def __init__(self,
            key,
            raise_errors: bool = True
        ):
            self.key = key
            super().__init__(raise_errors)

        def __call__(self, columns, row, i):
            for col in columns:
                if col not in row:
                    self.error(f"Column '{col}' not found in data", section="map.call",
                               exception=exceptions.TransformerDataError)
                refs = row[col]
                for ref in refs:
                    for item in ref[self.key]:
                        yield item

    def __init__(self,
            properties_of,
            label_maker = None,
            branching_properties = None,
            columns=None,
            output_validator = None,
            multi_type_dict = None,
            raise_errors = True,
            key = "urls",
            **kwargs
        ):

        self.value_maker = self.ValueMaker(key, raise_errors)

        super().__init__(
            properties_of,
            self.value_maker,
            label_maker,
            branching_properties,
            columns,
            output_validator,
            multi_type_dict,
            raise_errors=raise_errors,
            **kwargs
        )

