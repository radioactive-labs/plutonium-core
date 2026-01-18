# Plutonium: The pre-alpha demo

- Introduce the project
- Install Rails
  ```bash
  rails new demo -c tailwind -j esbuild
  ```
- Install Plutonium
  ```bash
  bundle add plutonium
  rails g pu:core:install
  ```
- Install useful gems
  ```bash
  rails g pu:gem:annotated
  ```
- Install rodauth
  ```bash
  rails g pu:rodauth:install
  ```
- Create rodauth user account
  ```bash
  rails g pu:rodauth:account user
  ```
- Create blogging feature package
  ```bash
  rails g pu:pkg:feature blogging
  ```
- Create blog resource
  ```bash
  rails g pu:res:scaffold blog user:belongs_to slug:string title:string content:text state:string published_at:datetime
  ```
- Create dashboard app package
  ```bash
  rails g pu:pkg:app dashboard
  ```
- Connect the blog to the dashboard
  ```bash
  rails g pu:res:conn
  ```
- Scope dashboard to user

  ```ruby
  # packages/dashboard_app/lib/engine.rb

  config.after_initialize do
    scope_to_entity User, strategy: :current_user
    # add directives above.
  end
  ```

- Demonstrate queries

  ```ruby
  # packages/dashboard_app/lib/engine.rb

  def define_filters
    # define custom filters
    define_search -> (scope, search:) { scope.where("title LIKE ?", "%#{search}%") }
  end

  def define_scopes
    # define custom scopes
    define_scope :published, -> (scope) { scope.where(state: :published) }
    define_scope :drafts, -> (scope) { scope.where(state: :draft) }
  end

  def define_sorters
    # define custom sorters
    define_sorter :title
    define_sorter :content
  end
  ```

- Create a custom action

  ```ruby
  # packages/blogging/app/interactions/blogging/blog_interactions/publish.rb

  module Blogging
    module BlogInteractions
      class Publish < ResourceInteraction
        object :resource, class: Blog

        def execute
          errors.merge!(resource.errors) unless resource.update(state: "published", published_at: Time.current)
          resource
        end
      end
    end
  end
  ```

  ```ruby
  # packages/blogging/app/presenters/blogging/blog_presenter.rb

    define_interactive_action :publish, label: 'Publish',
                                        interaction: BlogInteractions::Publish,
                                        icon: "outline/book",
                                        color: :green
  ```

- Create blog_comment resource
  ```bash
  rails g pu:res:scaffold blog_comment blogging/blog:belongs_to user:belongs_to content:text
  ```
- Define associations

  ```ruby
  # packages/blogging/app/models/blogging/blog.rb

  has_many :comments
  ```

  ```ruby
  # packages/blogging/app/policies/blogging/blog_policy.rb

   def permitted_attributes_for_show
     super + [:comments]
   end
  ```

- Connect comments to demonstrate auto linking
  ```bash
  rail g pu:res:conn
  ```
- Demonstrate plutonium association panels

  ```ruby
  # packages/blogging/app/policies/blogging/blog_policy.rb

  def permitted_attributes_for_show
      super
  end

  def permitted_associations
  	%i[comments]
  end
  ```

  19. Demonstrate nested_attributes

  ```ruby
  accepts_nested_attributes_for :comments, reject_if: :all_blank

  define_nested_input  :comments, inputs:  %i[user content], limit:  1  do |input|
  	input.define_field_input  :content, type:  :markdown
  end
  ```

- Create a custom field renderer

  ```bash
  rails g pu:field:renderer markdown
  bundle add redcarpet markdown
  ```

  ```ruby
  Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink:  true).render "content"
  ```

- Create a custom field input

  ```bash
  rails g pu:field:input
  ```

  https://github.com/Ionaru/easy-markdown-editor

  ```html
  # app/views/layouts/resource.html.erb <% layout.with_assets do %>
  <link
    rel="stylesheet"
    href="https://unpkg.com/easymde/dist/easymde.min.css"
  />
  <script src="https://unpkg.com/easymde/dist/easymde.min.js"></script>
  <% end %>
  ```

  ```bash
  rails g stimulus markdown_input
  ```

  ```js
  // app/javascript/controllers/markdown_input_controller.js

  connect() {
  	console.log("markdown-input connected", this.element)

      this.markdown = new EasyMDE({
  		element: this.element,
  	    toolbar: ["bold", "italic", "heading", "|", "quote"]
  	})
  }

  disconnect() {
    this.markdown.toTextArea()
    this.markdown = null
  }
  ```

  ```ruby
  # app/plutonium/fields/inputs/markdown_input.rb

    class MarkdownInput < Plutonium::Core::Fields::Inputs::Base
      def render
        form.input name, **options
      end

      private

      def input_options
        {input_html: {data: {controller: "markdown-input"}}}
      end
    end
  ```

  ```bash
  rails g pu:core:assets
  ```
