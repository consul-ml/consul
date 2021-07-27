require "rails_helper"

describe Document do
  it_behaves_like "document validations", "budget_investment_document"
  it_behaves_like "document validations", "proposal_document"

  it "stores attachments with Active Storage" do
    document = create(:document, attachment: File.new("spec/fixtures/files/clippy.pdf"))

    expect(document.attachment).to be_attached
    expect(document.attachment.filename).to eq "clippy.pdf"
  end

  describe "#url" do
    it "does not depend on the title of the document" do
      document = create(:document, :proposal_document, title: "Original title")
      original_url = document.url

      document.update!(title: "Modified title")

      expect(document.url).to eq original_url
    end
  end

  context "scopes" do
    describe "#admin" do
      it "returns admin documents" do
        admin_document = create(:document, :admin)

        expect(Document.admin).to eq [admin_document]
      end

      it "does not return user documents" do
        create(:document, admin: false)

        expect(Document.admin).to be_empty
      end
    end
  end
end
