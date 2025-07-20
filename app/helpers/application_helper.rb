module ApplicationHelper
  def ddns_status_tooltip(status, last_update = nil)
    case status
    when :healthy
      base = "DDNS is running normally"
      base += " • Last updated #{time_ago_in_words(last_update)} ago" if last_update
      base
    when :updating
      "DDNS is currently updating DNS records"
    when :error
      base = "DDNS encountered an error"
      base += " • Last attempt #{time_ago_in_words(last_update)} ago" if last_update
      base
    when :stopped
      "DDNS is enabled but container is stopped"
    when :disabled
      "Dynamic DNS is disabled"
    else
      "DDNS status unknown"
    end
  end
end
