# == Schema Information
# Schema version: 20230717201410
#
# Table name: foi_attachments
#
#  id                    :integer          not null, primary key
#  content_type          :text
#  filename              :text
#  charset               :text
#  display_size          :text
#  url_part_number       :integer
#  within_rfc822_subject :text
#  incoming_message_id   :integer
#  hexdigest             :string(32)
#  created_at            :datetime
#  updated_at            :datetime
#  prominence            :string           default("normal")
#  prominence_reason     :text
#  masked_at             :datetime
#

require 'spec_helper'
require 'models/concerns/message_prominence'

RSpec.describe FoiAttachment do
  it_behaves_like 'concerns/message_prominence', :body_text

  describe '.binary' do
    subject { described_class.binary }

    before do
      FactoryBot.create(:body_text)
      FactoryBot.create(:html_attachment)
    end

    let(:binary_attachments) do
      [FactoryBot.create(:pdf_attachment),
       FactoryBot.create(:rtf_attachment),
       FactoryBot.create(:jpeg_attachment),
       FactoryBot.create(:unknown_attachment)]
    end

    it { is_expected.to match_array(binary_attachments) }
  end

  describe '#body=' do

    it "sets the body" do
      attachment = FoiAttachment.new
      attachment.body = "baz"
      expect(attachment.body).to eq("baz")
    end

    it "sets the size" do
      attachment = FoiAttachment.new
      attachment.body = "baz"
      expect(attachment.body).to eq("baz")
      expect(attachment.display_size).to eq("0K")
    end

    it "reparses the body if it disappears" do
      load_raw_emails_data
      im = incoming_messages(:useless_incoming_message)
      im.extract_attachments!
      main = im.get_main_body_text_part
      orig_body = main.body
      main.delete_cached_file!
      expect {
        im.get_main_body_text_part.body
      }.not_to raise_error
      main.delete_cached_file!
      main = im.get_main_body_text_part
      expect(main.body).to eq(orig_body)
    end

    it 'can parse raw email and read attachment inside DB transaction' do
      im = FactoryBot.create(:plain_incoming_message)
      FoiAttachment.transaction do
        expect { im.get_text_for_indexing_full }.to_not raise_error
        main_part = im.get_main_body_text_part
        expect(main_part.body).to match(/That's so totally a rubbish question/)
      end
    end

    it 'does not update hexdigest if already present' do
      attachment = FoiAttachment.new(hexdigest: 'ABC')
      expect { attachment.body = 'foo' }.to_not change { attachment.hexdigest }
    end

  end

  describe '#body' do

    context 'when masked' do
      let(:foi_attachment) { FactoryBot.create(:body_text) }

      it 'returns a binary encoded string when newly created' do
        expect(foi_attachment.body.encoding.to_s).to eq('ASCII-8BIT')
      end

      it 'returns a binary encoded string when saved' do
        foi_attachment_2 = FoiAttachment.find(foi_attachment.id)
        expect(foi_attachment_2.body.encoding.to_s).to eq('ASCII-8BIT')
      end
    end

    context 'when unmasked and mask job is not queued' do
      let(:foi_attachment) { FactoryBot.create(:body_text, :unmasked) }

      it 'calls the FoiAttachmentMaskJob now and return the masked body' do
        expect(FoiAttachmentMaskJob).to receive(:perform_now).
          with(foi_attachment).
          and_invoke(-> (_) {
            # mock the job
            foi_attachment.update(body: 'maskedbody', masked_at: Time.zone.now)
          })

        expect(foi_attachment.body).to eq('maskedbody')
      end
    end

    context 'when unmasked and mask job is already queued' do
      let(:foi_attachment) { FactoryBot.create(:body_text, :unmasked) }

      before do
        allow(FoiAttachmentMaskJob).to receive(:perform_now).and_return(false)
      end

      it 'raises missing attachment expection' do
        expect { foi_attachment.body }.to raise_error(
          FoiAttachment::MissingAttachment,
          "job already queued (ID=#{foi_attachment.id})"
        )
      end
    end

  end

  describe '#body_as_text' do

    it 'has a valid UTF-8 string when newly created' do
      foi_attachment = FactoryBot.create(:body_text)
      expect(foi_attachment.body_as_text.string.encoding.to_s).to eq('UTF-8')
      expect(foi_attachment.body_as_text.string.valid_encoding?).to be true
    end

    it 'has a valid UTF-8 string when saved' do
      foi_attachment = FactoryBot.create(:body_text)
      foi_attachment = FoiAttachment.find(foi_attachment.id)
      expect(foi_attachment.body_as_text.string.encoding.to_s).to eq('UTF-8')
      expect(foi_attachment.body_as_text.string.valid_encoding?).to be true
    end


    it 'has a true scrubbed? value if the body has been coerced to valid UTF-8' do
      foi_attachment = FactoryBot.create(:body_text)
      foi_attachment.body = "\x0FX\x1C\x8F\xA4\xCF\xF6\x8C\x9D\xA7\x06\xD9\xF7\x90lo"
      expect(foi_attachment.body_as_text.scrubbed?).to be true
    end

    it 'has a false scrubbed? value if the body has not been coerced to valid UTF-8' do
      foi_attachment = FactoryBot.create(:body_text)
      foi_attachment.body = "κόσμε"
      expect(foi_attachment.body_as_text.scrubbed?).to be false
    end

  end

  describe '#default_body' do

    it 'returns valid UTF-8 for a text attachment' do
      foi_attachment = FactoryBot.create(:body_text)
      expect(foi_attachment.default_body.encoding.to_s).to eq('UTF-8')
      expect(foi_attachment.default_body.valid_encoding?).to be true
    end

    it 'returns binary for a PDF attachment' do
      foi_attachment = FactoryBot.create(:pdf_attachment)
      expect(foi_attachment.default_body.encoding.to_s).to eq('ASCII-8BIT')
    end

  end

  describe '#unmasked_body' do

    let(:foi_attachment) { FactoryBot.create(:body_text) }
    subject(:unmasked_body) { foi_attachment.unmasked_body }

    before do
      allow(foi_attachment).to receive(:raw_email).
        and_return(double.as_null_object)
    end

    context 'when mail handler finds original attachment by hexdigest' do
      before do
        allow(MailHandler).to receive(:attachment_body_for_hexdigest).
          and_return('hereistheunmaskedtext')
      end

      it 'returns the attachment body from the raw email' do
        is_expected.to eq('hereistheunmaskedtext')
      end
    end

    context 'when mail handler can not original attachment by hexdigest' do
      before do
        allow(MailHandler).to receive(:attachment_body_for_hexdigest).
          and_raise(MailHandler::MismatchedAttachmentHexdigest)
      end

      context 'when attachment has prominence' do
        let(:foi_attachment) do
          FactoryBot.create(:body_text, prominence: 'hidden')
        end

        it 'raises missing attachment expection' do
          expect { unmasked_body }.to raise_error(
            FoiAttachment::MissingAttachment,
            "prominence not public (ID=#{foi_attachment.id})"
          )
        end
      end

      context 'when attachment file is unattached' do
        let(:foi_attachment) do
          FactoryBot.create(:body_text, filename: nil)
        end

        it 'raises missing attachment expection' do
          expect { unmasked_body }.to raise_error(
            FoiAttachment::MissingAttachment,
            "file not attached (ID=#{foi_attachment.id})"
          )
        end
      end

      context 'when unable to find original attachment through other means' do
        before do
          allow(MailHandler).to receive(
            :attempt_to_find_original_attachment_attributes
          ).and_return(nil)
        end

        it 'raises missing attachment expection' do
          expect { unmasked_body }.to raise_error(
            FoiAttachment::MissingAttachment,
            "unable to find original (ID=#{foi_attachment.id})"
          )
        end
      end

      context 'when able to find original attachment through other means' do
        before do
          allow(MailHandler).to receive(
            :attempt_to_find_original_attachment_attributes
          ).and_return(hexdigest: 'ABC', body: 'hereistheunmaskedtext')
        end

        it 'updates the hexdigest' do
          expect { unmasked_body }.to change { foi_attachment.hexdigest }.
            to('ABC')
        end

        it 'returns the attachment body from the raw email' do
          is_expected.to eq('hereistheunmaskedtext')
        end
      end
    end

  end

  describe 'masked?' do

    let(:foi_attachment) do
      FoiAttachment.new(body: 'foo', masked_at: Time.zone.now)
    end

    subject { foi_attachment.masked? }

    it { is_expected.to eq(true) }

    context 'without file attached' do
      let(:foi_attachment) { FoiAttachment.new(masked_at: Time.zone.now) }
      it { is_expected.to eq(false) }
    end

    context 'without masked_at' do
      let(:foi_attachment) { FoiAttachment.new(body: 'foo') }
      it { is_expected.to eq(false) }
    end

    context 'when masked_at is in the future' do
      let(:foi_attachment) do
        FoiAttachment.new(body: 'foo', masked_at: Time.zone.now + 1.day)
      end

      it { is_expected.to eq(false) }
    end

  end

  describe '#main_body_part?' do
    subject { attachment.main_body_part? }

    let(:message) { FactoryBot.build(:incoming_message_with_attachments) }

    context 'when the attachment is the main body' do
      let(:attachment) { message.get_main_body_text_part }
      it { is_expected.to eq(true) }
    end

    context 'when the attachment is not the main body' do
      let(:attachment) { message.get_attachments_for_display.first }
      it { is_expected.to eq(false) }
    end
  end

  describe '#filename=' do
    it 'strips null bytes' do
      attachment = FactoryBot.build(:pdf_attachment)
      attachment.filename = "Tender Loving Care Trust (Europe).pdf\u0000"
      expect(attachment.filename).to eq('Tender Loving Care Trust (Europe).pdf')
    end
  end

  describe '#ensure_filename!' do

    it 'should create a filename for an instance with a blank filename' do
      attachment = FoiAttachment.new
      attachment.filename = ''
      attachment.ensure_filename!
      expect(attachment.filename).to eq('attachment.bin')
    end

  end

  describe '#has_body_as_html?' do

    it 'should be true for a pdf attachment' do
      expect(FactoryBot.build(:pdf_attachment).has_body_as_html?).to be true
    end

    it 'should be false for an html attachment' do
      expect(FactoryBot.build(:html_attachment).has_body_as_html?).to be false
    end

  end

  describe '#name_of_content_type' do
    subject { foi_attachment.name_of_content_type }

    before do
      stub = { 'content/named' => 'Named content' }
      stub_const("#{described_class}::CONTENT_TYPE_NAMES", stub)
    end

    let(:foi_attachment) do
      FactoryBot.build(:foi_attachment, content_type: content_type)
    end

    context 'when the content_type has a name' do
      let(:content_type) { 'content/named' }
      it { is_expected.to eq('Named content') }
    end

    context 'when the content_type has no name' do
      let(:content_type) { 'content/unnamed' }
      it { is_expected.to be_nil }
    end
  end
end
