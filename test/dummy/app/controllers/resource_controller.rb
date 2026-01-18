class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller

  private def current_user
    raise NotImplementedError, "#{self.class}#current_user must return a non nil value"
  end
  helper_method :current_user

  private def logout_url
    # return a logout url to render a logout link
  end
  helper_method :logout_url
end
