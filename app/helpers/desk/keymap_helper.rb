module Desk::KeymapHelper
  # Alt in a browser, ⌘ inside the native shell (see Desk.native_user_agent).
  def desk_modifier = Desk.modifier_for(request.user_agent)

  def desk_native? = Desk.native?(request.user_agent)
end
