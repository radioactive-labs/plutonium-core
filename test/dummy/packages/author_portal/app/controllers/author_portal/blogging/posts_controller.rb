class AuthorPortal::Blogging::PostsController < ::Blogging::PostsController
  include AuthorPortal::Concerns::Controller

  private

  # Override resource_params to automatically include current_user
  def resource_params
    super.merge(user: current_user)
  end
end
