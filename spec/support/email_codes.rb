module EmailCodes
  # @param code [String]
  # @return [String] a code of the same length that differs from it
  def wrong_code(code)
    digits = Shopper::EmailCode::DIGITS
    ((code.to_i + 1) % (10**digits)).to_s.rjust(digits, "0")
  end

  # @param mail [Mail::Message]
  # @return [String, nil]
  def mailed_code(mail = ActionMailer::Base.deliveries.last)
    mail.text_part.body.to_s[/\b\d{#{Shopper::EmailCode::DIGITS}}\b/o]
  end
end

RSpec.configure { |config| config.include EmailCodes }
