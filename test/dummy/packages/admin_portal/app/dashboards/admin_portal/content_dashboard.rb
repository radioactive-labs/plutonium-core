module AdminPortal
  # A second admin dashboard, generated with `pu:dashboard`, so the sidebar's
  # Dashboards group lists more than one entry.
  class ContentDashboard < Plutonium::Dashboard::Base
    presents label: "Content", description: "What the blog is publishing", icon: Phlex::TablerIcons::Article

    # The choices are "All" plus the post definition's scopes.
    filter :status, scopes: ::Blogging::Post
    link :posts, label: "All posts", icon: Phlex::TablerIcons::FileText, href: ->(d) { d.resource_url_for(::Blogging::Post, parent: nil) }
    link :hidden, href: "/nowhere", condition: -> { false }
    link :no_href, href: -> {}

    # The card opens the posts list on the chosen scope.
    metric(:posts, span: 4, icon: Phlex::TablerIcons::FileText, href: -> { filtered_url(::Blogging::Post) }) do
      posts.count
    end

    metric(:comments, span: 4, icon: Phlex::TablerIcons::Message) { authorized_resource_scope(Comment).count }

    metric(:flagged, span: 4, positive: :down, description: "Comments awaiting review") do
      authorized_resource_scope(Comment).where(flagged: true).count
    end

    chart(:by_status, type: :column, span: :full) do
      posts.group(:status).count.transform_keys { |status| status.to_s.titleize }
    end

    private

    def posts = filtered(::Blogging::Post)
  end
end
