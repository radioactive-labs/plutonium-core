class Blogging::PostDefinition < Blogging::ResourceDefinition
  # Page titles
  index_page_title "Blog Posts"
  index_page_description "Manage your blog content"

  # Field customizations
  field :body, as: :text

  # Column customizations
  column :user, label: "Author"

  # Computed column
  column :comment_count do |post|
    post.comments.count
  end

  # Search configuration
  search do |scope, query|
    scope.where("title LIKE ? OR body LIKE ?", "%#{query}%", "%#{query}%")
  end

  # Scopes
  scope :published
  scope :drafts

  # Filters
  filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains

  # Sorting
  sort :title
  sort :created_at
  sort :published

  # Default sort
  default_sort :created_at, :desc

  # Register the publish action
  action :publish, interaction: Blogging::PublishPost
  action :schedule, interaction: Blogging::SchedulePost
end
