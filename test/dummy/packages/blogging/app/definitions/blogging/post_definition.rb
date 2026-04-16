class Blogging::PostDefinition < Blogging::ResourceDefinition
  # Page titles
  index_page_title "Blog Posts"
  index_page_description "Manage your blog content"

  # Field customizations
  field :body, as: :text

  # Column customizations
  column :user, label: "Author"

  # Search configuration
  search do |scope, query|
    scope.where("title LIKE ? OR body LIKE ?", "%#{query}%", "%#{query}%")
  end

  # Scopes
  scope :published
  scope :drafts
  scope :archived

  # Filters
  filter :title, with: :text, predicate: :contains
  filter :status, with: :select, choices: Blogging::Post.statuses.keys
  filter :user, with: :association

  # Sorting
  sort :title
  sort :created_at
  sort :status

  # Default sort
  default_sort :created_at, :desc

  # Actions
  action :publish, interaction: Blogging::PublishPost
  action :archive, interaction: Blogging::ArchivePost
  action :touch, interaction: Blogging::TouchPost, category: :primary, confirmation: false
end
