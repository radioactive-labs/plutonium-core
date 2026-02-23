# frozen_string_literal: true

OrgPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::User
end

Rails.application.routes.draw do
  mount OrgPortal::Engine, at: "/org"
end
