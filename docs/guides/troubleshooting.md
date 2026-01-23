# Troubleshooting

Common issues and their solutions when working with Plutonium.

## Resource Class Detection

### "Failed to determine the resource class" Error

**Error messages:**
```
NameError: Failed to determine the resource class for MyPortal::PostMetadataController.
Rails singularized "PostMetadata" to "PostMetadatum", but "PostMetadata" exists.
Add an inflection rule to config/initializers/inflections.rb.
```

or:

```
NameError: Failed to determine the resource class.
Please call `controller_for(MyResource)` in MyPortal::MyResourceController.
```

**Cause:** Plutonium infers the resource class from the controller name by singularizing it. For resources with names that don't follow standard Rails pluralization (like `PostMetadata`), Rails may singularize incorrectly (`PostMetadata` → `PostMetadatum`). Plutonium detects this and provides a helpful error message.

**Solution:** Add a custom inflection rule in `config/initializers/inflections.rb`:

```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  # Preserve "Metadata" when singularizing (e.g., PostMetadata stays PostMetadata)
  inflect.singular(/(M)etadata$/i, '\1etadata')
end
```

This ensures Rails correctly handles the singularization throughout your application, including:
- Controller to model resolution
- Route generation
- Association lookups

**Alternative:** If you can't modify inflections, explicitly set the resource class in your controller:

```ruby
class MyPortal::PostMetadataController < MyPortal::ResourceController
  controller_for Blogging::PostMetadata
end
```

### Common Words Needing Inflection Rules

| Word | Without Rule | With Rule | Inflection |
|------|--------------|-----------|------------|
| Metadata | `PostMetadatum` | `PostMetadata` | `inflect.singular(/(M)etadata$/i, '\1etadata')` |
| Media | `PostMedium` | `PostMedia` | `inflect.singular(/(M)edia$/i, '\1edia')` |
| Data | `PostDatum` | `PostData` | `inflect.singular(/(D)ata$/i, '\1ata')` |
| Criteria | `SearchCriterium` | `SearchCriteria` | `inflect.singular(/(C)riteria$/i, '\1riteria')` |

## URL Generation

### Wrong URLs for Nested Resources

**Symptom:** URLs for nested resources include unexpected IDs or route to the wrong path.

**Cause:** Rails "param recall" fills in missing parameters from the current request when generating URLs. This can cause issues when both top-level and nested routes exist for the same resource.

**Solution:** Plutonium handles this automatically by using named route helpers for nested resources. Ensure you're using `resource_url_for` instead of `url_for`:

```ruby
# Good - uses Plutonium's smart URL generation
resource_url_for(@comment, parent: @post)

# May have issues with param recall
url_for(controller: 'comments', action: 'show', id: @comment.id)
```

## Need More Help?

If you encounter an issue not covered here, please [open an issue](https://github.com/radioactive-labs/plutonium-core/issues) on GitHub.

## Related

- [Nested Resources Guide](./nested-resources)
- [Adding Resources Guide](./adding-resources)
- [Rails Inflections Documentation](https://api.rubyonrails.org/classes/ActiveSupport/Inflector/Inflections.html)
