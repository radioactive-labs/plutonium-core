class Catalog::SpecDefinition < Catalog::ResourceDefinition
  structured_input :payload do |f|
    f.input :title
    f.input :notes
  end

  structured_input :rows, repeat: 5 do |f|
    f.input :key
    f.input :value
  end
end
