# frozen_string_literal: true

require "spec_helper"

describe "Initiative signing", type: :system do
  let(:organization) { create(:organization) }
  let(:initiative) do
    create(:initiative, :published, organization: organization)
  end
  let(:initiative_with_user_user_extra_fields) do
    create(:initiative, :published, :with_user_extra_fields_collection, organization: organization)
  end
  let(:authorized_user) { create(:user, :confirmed, organization: organization) }

  before do
    allow(Decidim::Initiatives)
      .to receive(:do_not_require_authorization)
      .and_return(true)
    switch_to_host(organization.host)
    login_as authorized_user, scope: :user
  end

  context "when the user has not signed the initiative yet and signs it" do
    context "when the user has a verified user group" do
      let!(:user_group) { create :user_group, :verified, users: [authorized_user], organization: authorized_user.organization }

      it "votes as a user group" do
        vote_initiative(initiative, user_name: user_group.name)
      end

      it "votes as themselves" do
        vote_initiative(initiative, user_name: authorized_user.name)
      end
    end

    it "adds the signature" do
      vote_initiative(initiative)
    end
  end

  context "when the user has signed the initiative and unsigns it" do
    context "when the user has a verified user group" do
      let!(:user_group) { create :user_group, :verified, users: [authorized_user], organization: authorized_user.organization }

      it "removes the signature" do
        vote_initiative(initiative, user_name: user_group.name)

        click_button user_group.name

        within ".view-side" do
          expect(page).to have_content("0\nSIGNATURE")
        end
      end
    end

    it "removes the signature" do
      vote_initiative(initiative)

      within ".view-side" do
        expect(page).to have_content("1\nSIGNATURE")
        click_button "Sign"
        expect(page).to have_content("0\nSIGNATURE")
      end
    end
  end

  context "when the initiative requires user extra fields collection to be signed" do
    context "when the user has not signed the initiative yet and signs it" do
      context "when the user has a verified user group" do
        let!(:user_group) { create :user_group, :verified, users: [authorized_user], organization: authorized_user.organization }

        it "votes as a user group" do
          vote_initiative(initiative_with_user_user_extra_fields, user_name: user_group.name)
        end

        it "votes as themselves" do
          vote_initiative(initiative_with_user_user_extra_fields, user_name: authorized_user.name)
        end
      end

      it "adds the signature" do
        vote_initiative(initiative_with_user_user_extra_fields)
      end

      it "vote is forbidden unless personal data is filled" do
        visit decidim_initiatives.initiative_path(initiative_with_user_user_extra_fields)
        within ".view-side" do
          expect(page).to have_content("0\nSIGNATURE")
          click_on "Sign"
        end
        click_button "Continue"

        expect(page).to have_content "error"

        visit decidim_initiatives.initiative_path(initiative_with_user_user_extra_fields)
        within ".view-side" do
          expect(page).to have_content("0\nSIGNATURE")
          click_on "Sign"
        end
      end
    end
  end

  def vote_initiative(initiative, user_name: nil)
    visit decidim_initiatives.initiative_path(initiative)

    within ".view-side" do
      expect(page).to have_content("0\nSIGNATURE")
      click_on "Sign"
    end

    if user_name.present?
      within "#user-identities" do
        click_on user_name
      end
    end

    if has_content?("Complete your data")
      fill_in :initiatives_vote_name_and_surname, with: authorized_user.name
      fill_in :initiatives_vote_document_number, with: "012345678A"
      fill_in :initiatives_vote_date_of_birth, with: 30.years.ago
      fill_in :initiatives_vote_postal_code, with: "01234"

      click_button "Continue"
    end

    within ".view-side" do
      expect(page).to have_content("1\nSIGNATURE")
    end
  end
end
