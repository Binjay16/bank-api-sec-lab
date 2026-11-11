require "csv"
require "zlib"

class StatementsController < ApplicationController
  EXPORT_DIR = Rails.root.join("tmp", "exports")

  # File names are generated server-side. No user input reaches a shell or a path.
  def export
    account = current_user.accounts.find(params[:account_id])
    FileUtils.mkdir_p(EXPORT_DIR)

    token = SecureRandom.hex(16)
    Zlib::GzipWriter.open(EXPORT_DIR.join("#{current_user.id}-#{token}.csv.gz").to_s) do |gz|
      gz.write(build_csv(account))
    end
    render json: { file: "#{token}.csv.gz" }
  end

  # The requested name is only ever *compared* against files that exist in the
  # current user's namespace; it is never used to build a path.
  def download
    wanted = "#{current_user.id}-#{params[:file]}"
    path   = EXPORT_DIR.directory? ? EXPORT_DIR.children.find { |p| p.basename.to_s == wanted } : nil
    return render(json: { error: "not found" }, status: :not_found) unless path

    send_file path, type: "application/gzip", disposition: "attachment"
  end

  private

  def build_csv(account)
    CSV.generate do |out|
      out << %w[date from to amount_cents memo]
      rows(account).each do |t|
        out << [t.created_at.iso8601, t.from_account.number, t.to_account.number,
                t.amount_cents, csv_safe(t.memo)]
      end
    end
  end

  def rows(account)
    Transfer.where(from_account_id: account.id).or(Transfer.where(to_account_id: account.id)).order(:created_at)
  end

  # Neutralise spreadsheet formula injection (=, +, -, @, tab, CR).
  def csv_safe(value)
    text = value.to_s
    text.match?(/\A[=+\-@\t\r]/) ? "'#{text}" : text
  end
end
