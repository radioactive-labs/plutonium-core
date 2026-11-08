class Hr::EmployeeDefinition < Hr::ResourceDefinition
  action :promote, interaction: Hr::PromoteEmployee
end
