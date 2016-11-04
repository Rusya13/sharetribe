module NewLayoutViewUtils
  extend ActionView::Helpers::TranslationHelper

  Feature = EntityUtils.define_builder(
    [:title, :string, :mandatory],
    [:name, :symbol, :mandatory],
    [:enabled_for_user, :bool, :mandatory],
    [:enabled_for_community, :bool, :mandatory],
    [:disabled_for_user, :bool, default: false],
    [:disabled_for_community, :bool, default: false]
  )

  # Describes feature relationships:
  # { feature: :required }
  REQUIRED_FEATURES = {
    searchpage_v1: :topbar_v1
  }

  FEATURES = [
    { title: t("admin.communities.new_layout.new_topbar"),
      name: :topbar_v1
    },
  ]

  SEARCHPAGE = [
    { title: t("admin.communities.new_layout.searchpage"),
      name:  :searchpage_v1,
    },
  ]

  module_function

  def features(community_id, person_id, private_community, clp_enabled)
    person_flags = FeatureFlagService::API::Api.features.get_for_person(community_id: community_id, person_id: person_id).data[:features]
    community_flags = FeatureFlagService::API::Api.features.get_for_community(community_id: community_id).data[:features]

    fs =
      if(can_manage_searchpage?(person_flags, community_flags, private_community, clp_enabled))
        FEATURES + SEARCHPAGE
      else
        FEATURES
      end

    fs.map { |f|
      Feature.build({
        title: f[:title],
        name: f[:name],
        enabled_for_user: person_flags.include?(f[:name]),
        enabled_for_community: community_flags.include?(f[:name]),
        disabled_for_user: topbar_flag_disabled?(f, person_flags),
        disabled_for_community: topbar_flag_disabled?(f, community_flags)
      })}
  end

  # Takes a map of features
  # {
  #  "foo" => "true",
  #  "bar" => "true",
  # }
  # and returns the keys as symbols from the entries
  # that hold value "true".
  def enabled_features(feature_params)
    allowed_features = (FEATURES + SEARCHPAGE).map { |f| f[:name] }
    features = feature_params.select { |key, value| value == "true" }
                 .keys
                 .map(&:to_sym)
                 .select { |k| allowed_features.include?(k) }
    add_required_features(features)
  end

  # From the list of features, selects the ones
  # that are disabled, ie. not included in the
  # list of enabled features.
  def resolve_disabled(enabled)
     all_enabled = add_required_features(enabled)
     features = (FEATURES + SEARCHPAGE).map { |f| f[:name]}
       .select { |f| !all_enabled.include?(f) }
  end

  def can_manage_searchpage?(person_flags, community_flags, private_community, clp_enabled)
    if(private_community)
      clp_enabled &&
      (person_flags + community_flags).include?(:manage_searchpage)
    else
      (person_flags + community_flags).include?(:manage_searchpage)
    end
  end

  def add_required_features(features)
    (features | REQUIRED_FEATURES.values_at(*features)).compact
  end

  def topbar_flag_disabled?(fl, flags)
    #topbar is required with other flags and thus disabled
    fl[:name] == :topbar_v1 &&
      !flags.reject{ |f| [:topbar_v1, :manage_searchpage].include?(f) }.empty?
  end
end
