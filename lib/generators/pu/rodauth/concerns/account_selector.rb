module Pu
  module Rodauth
    module Concerns
      module AccountSelector
        def self.included(base)
          base.send :argument, :account_name, type: :string, desc: "name of the account model. "
          base.send :class_option, :migration_name, type: :string, desc: "[CONFIG] name of the generated migration file"
        end

        private

        def table
          @table ||= account_name.underscore.pluralize
        end

        def account_path
          @account_path ||= account_name.singularize.underscore
        end

        def table_prefix
          @table_prefix ||= account_path.tr("/", "_")
        end
      end
    end
  end
end
