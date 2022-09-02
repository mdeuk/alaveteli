require 'spec_helper'

RSpec.describe AdminIncomingMessageController, "when administering incoming messages" do

  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:pro_admin_user) { FactoryBot.create(:pro_admin_user) }

  describe 'when destroying an incoming message' do

    before(:each) do
      sign_in(admin_user)
      load_raw_emails_data
    end

    before do
      @im = incoming_messages(:useless_incoming_message)
    end

    it "destroys the ActiveStorage attachment record" do
      file = @im.raw_email.file
      expect(file.attached?).to eq true
      post :destroy, params: { id: @im.id }
      expect { file.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'asks the incoming message to destroy itself' do
      allow(IncomingMessage).to receive(:find).and_return(@im)
      expect(@im).to receive(:destroy)
      post :destroy, params: { :id => @im.id }
    end

    it 'expires the file cache for the associated info_request' do
      info_request = FactoryBot.create(:info_request)
      allow(@im).to receive(:info_request).and_return(info_request)
      allow(IncomingMessage).to receive(:find).and_return(@im)
      expect(@im.info_request).to receive(:expire).with(:preserve_database_cache => true)
      post :destroy, params: { :id => @im.id }
    end

    context 'if the request is embargoed', feature: :alaveteli_pro do
      before do
        @im.info_request.create_embargo
      end

      context 'as non-pro admin' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect {
            post :destroy, params: { id: @im }
          }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context 'as pro admin' do
        before { sign_in(pro_admin_user) }

        it 'rediects to request admin' do
          post :destroy, params: { id: @im }
          expect(response).to redirect_to admin_request_url(@im.info_request)
        end
      end
    end
  end

  describe 'when redelivering an incoming message' do

    before(:each) do
      sign_in(admin_user)
      load_raw_emails_data
    end

    let(:previous_info_request) { FactoryBot.build(:info_request) }
    let(:incoming_message) do
      FactoryBot.create(:incoming_message, info_request: previous_info_request)
    end
    let(:destination_info_request) { FactoryBot.create(:info_request) }

    it 'expires the file cache for the previous request' do
      allow(IncomingMessage).to receive(:find).and_return(incoming_message)
      expect(previous_info_request).to receive(:expire)
      post :redeliver, params: {
                         :id => incoming_message.id,
                         :url_title => destination_info_request.url_title
                       }
    end

    it 'should succeed, even if a duplicate xapian indexing job is created' do

      with_duplicate_xapian_job_creation do
        post :redeliver, params: {
                           :id => incoming_message.id,
                           :url_title => destination_info_request.url_title
                         }
      end

    end

    it 'shouldn\'t do anything if no message_id is supplied' do
      post :redeliver, params: {
                         :id => incoming_message.id,
                         :url_title => ''
                       }
      # It shouldn't delete this message
      assert_equal IncomingMessage.exists?(incoming_message.id), true
      # Should show an error to the user
      assert_equal flash[:error], "You must supply at least one request to redeliver the message to."
      expect(response).to redirect_to admin_request_url(incoming_message.info_request)
    end

    context 'if the request is embargoed', feature: :alaveteli_pro do
      before do
        incoming_message.info_request.create_embargo
      end

      context 'as non-pro admin' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect {
            post :redeliver, params: {
              id: incoming_message,
              url_title: destination_info_request.url_title
            }
          }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context 'as pro admin' do
        before { sign_in(pro_admin_user) }

        it 'redirects to destination request admin' do
          post :redeliver, params: {
            id: incoming_message,
            url_title: destination_info_request.url_title
          }
          expect(response).to redirect_to \
            admin_request_url(destination_info_request)
        end
      end
    end
  end

  describe 'when editing an incoming message' do

    before do
      sign_in(admin_user)
      @incoming = FactoryBot.create(:incoming_message)
    end

    it 'should be successful' do
      get :edit, params: { :id => @incoming.id }
      expect(response).to be_successful
    end

    it 'should assign the incoming message to the view' do
      get :edit, params: { :id => @incoming.id }
      expect(assigns[:incoming_message]).to eq(@incoming)
    end

    context 'if the request is embargoed', feature: :alaveteli_pro do
      before do
        @incoming.info_request.create_embargo
      end

      context 'as non-pro admin' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect {
            get :edit, params: { id: @incoming }
          }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context 'as pro admin' do
        before { sign_in(pro_admin_user) }

        it 'is successful' do
          get :edit, params: { id: @incoming }
          expect(response).to be_successful
        end
      end
    end
  end

  describe 'when updating an incoming message' do

    before do
      sign_in(admin_user)
      @incoming = FactoryBot.create(:incoming_message, :prominence => 'normal')
      @default_params = {
        id: @incoming.id,
        incoming_message: {
          prominence: 'hidden',
          prominence_reason: 'dull',
          tag_string: 'foo'
        }
      }
    end

    def make_request(params=@default_params)
      post :update, params: params
    end

    it 'should save the prominence of the message' do
      make_request
      @incoming.reload
      expect(@incoming.prominence).to eq('hidden')
    end

    it 'should save a prominence reason for the message' do
      make_request
      @incoming.reload
      expect(@incoming.prominence_reason).to eq('dull')
    end

    it 'should save a tag string for the message' do
      make_request
      @incoming.reload
      expect(@incoming.tag_string).to eq('foo')
    end

    it 'should log an "edit_incoming" event on the info_request' do
      allow(@controller).to receive(:admin_current_user).and_return("Admin user")
      make_request
      @incoming.reload
      last_event = @incoming.info_request_events.last
      expect(last_event.event_type).to eq('edit_incoming')
      expect(last_event.params).to eq(
        incoming_message_id: @incoming.id,
        editor: 'Admin user',
        old_prominence: 'normal',
        prominence: 'hidden',
        old_prominence_reason: nil,
        prominence_reason: 'dull',
        old_tag_string: '',
        tag_string: 'foo'
      )
    end

    it 'should expire the file cache for the info request' do
      info_request = FactoryBot.create(:info_request)
      allow(IncomingMessage).to receive(:find).and_return(@incoming)
      allow(@incoming).to receive(:info_request).and_return(info_request)
      expect(info_request).to receive(:expire)
      make_request
    end

    context 'if the incoming message saves correctly' do

      it 'should redirect to the admin info request view' do
        make_request
        expect(response).to redirect_to admin_request_url(@incoming.info_request)
      end

      it 'should show a message that the incoming message has been updated' do
        make_request
        expect(flash[:notice]).to eq('Incoming message successfully updated.')
      end

    end

    context 'if the incoming message is not valid' do

      it 'should render the edit template' do
        make_request({:id => @incoming.id,
                      :incoming_message => {:prominence => 'fantastic',
                                            :prominence_reason => 'dull'}})
        expect(response).to render_template("edit")
      end

    end

    context 'if the request is embargoed', feature: :alaveteli_pro do
      before do
        @incoming.info_request.create_embargo
      end

      context 'as non-pro admin' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect {
            make_request
          }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context 'as pro admin' do
        before { sign_in(pro_admin_user) }

        it 'redirects to request admin' do
          make_request
          expect(response).to redirect_to \
            admin_request_url(@incoming.info_request)
        end
      end
    end
  end

  describe "when destroying multiple incoming messages" do
    let(:request) { FactoryBot.create(:info_request) }
    let(:spam1) { FactoryBot.create(
                    :incoming_message,
                    :subject => "Buy a watch!1!!",
                    :info_request => request) }
    let(:spam2) { FactoryBot.create(
                    :incoming_message,
                    :subject => "Best cheap w@tches!!1!",
                    :info_request => request) }
    let(:spam_ids) { [spam1.id, spam2.id] }

    before { sign_in(admin_user) }

    context "the user confirms deletion" do

      it "destroys the selected messages" do
        post :bulk_destroy, params: {
                              :request_id => request.id,
                              :ids => spam_ids.join(","),
                              :commit => "Yes"
                            }

        expect(IncomingMessage.where(:id => spam_ids)).to be_empty
      end

      it 'expires the file cache for the associated info_request' do
        allow(InfoRequest).to receive(:find).and_return(request)
        expect(request).to receive(:expire).with(:preserve_database_cache => true)
        post :bulk_destroy, params: {
                              :request_id => request.id,
                              :ids => spam_ids.join(","),
                              :commit => "Yes"
                            }
      end

      it "redirects back to the admin page for the request" do
        post :bulk_destroy, params: {
                              :request_id => request.id,
                              :ids => spam_ids.join(","),
                              :commit => "Yes"
                            }

        expect(response).to redirect_to(admin_request_url(request))
      end

      it "sets a success message in flash" do
        post :bulk_destroy, params: {
                              :request_id => request.id,
                              :ids => spam_ids.join(","),
                              :commit => "Yes"
                            }

        expect(response).to redirect_to(admin_request_url(request))
        expect(flash[:notice]).to eq("Incoming messages successfully destroyed.")
      end

      it "only destroys selected messages" do
        post :bulk_destroy, params: {
                              :request_id => request.id,
                              :ids => spam2.id,
                              :commit => "Yes"
                            }

        expect(IncomingMessage.where(:id => spam_ids)).to eq([spam1])
      end

      context "not all the messages can be destroyed" do

        it "set an error message in flash" do
          allow(spam2).to receive(:destroy).and_raise("random DB error")
          allow(IncomingMessage).to receive(:where).and_return([spam1, spam2])
          msg = "Incoming Messages #{spam2.id} could not be destroyed"
          post :bulk_destroy, params: {
                                :request_id => request.id,
                                :ids => spam_ids.join(","),
                                :commit => "Yes"
                              }

          expect(flash[:error]).to match(msg)
        end

      end

    end

    context "the user does not confirm deletion" do

      it "does not destroy the messages" do
        post :bulk_destroy, params: {
                              :request_id => request.id,
                              :ids => spam_ids.split(","),
                              :commit => "No"
                            }

        expect(IncomingMessage.where(:id => spam_ids)).to match_array([spam1, spam2])
      end

      it "redirects back to the admin page for the request" do
        post :bulk_destroy, params: {
                              :request_id => request.id,
                              :ids => spam_ids.join(","),
                              :commit => "No"
                            }

        expect(response).to redirect_to(admin_request_url(request))
      end

    end

    context 'if the request is embargoed', feature: :alaveteli_pro do
      before do
        request.create_embargo
      end

      context 'as non-pro admin' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect {
            post :bulk_destroy, params: {
              request_id: request, ids: spam_ids.join(","), commit: 'Yes'
            }
          }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context 'as pro admin' do
        before { sign_in(pro_admin_user) }

        it 'redirects to request admin' do
          post :bulk_destroy, params: {
            request_id: request, ids: spam_ids.join(","), commit: 'Yes'
          }
          expect(response).to redirect_to admin_request_url(request)
        end
      end
    end

  end

end
