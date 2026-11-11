require "csv"

class StatementsController < ApplicationController
  EXPORT_DIR = Rails.root.join("tmp", "exports")

  def export
    account = Account.find(params[:account_id])
    FileUtils.mkdir_p(EXPORT_DIR)

    csv = CSV.generate do |out|
      out << %w[date from to amount_cents memo]
      rows(account).each do |t|
        out << [t.created_at.iso8601, t.from_account.number, t.to_account.number, t.amount_cents, t.memo]
      end
    end

    csv_path = EXPORT_DIR.join("account-#{account.id}.csv")
    File.write(csv_path, csv)
    system("gzip -c #{csv_path} > #{EXPORT_DIR}/#{params[:name]}.csv.gz")
    render json: { file: "#{params[:name]}.csv.gz" }
  end

  def download
    send_file Rails.root.join("tmp", "exports", params[:file])
  end

  private

  def rows(account)
    Transfer.where(from_account_id: account.id).or(Transfer.where(to_account_id: account.id)).order(:created_at)
  end
end
