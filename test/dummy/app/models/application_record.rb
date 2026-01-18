class ApplicationRecord < ActiveRecord::Base
  include Plutonium::Resource::Record

  primary_abstract_class
end
