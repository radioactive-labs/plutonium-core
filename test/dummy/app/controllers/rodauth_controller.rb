# Base rodauth controller. Inherited by all account controllers.
class RodauthController < PlutoniumController
  include Plutonium::Rodauth::ControllerMethods
end
