export 'src/core/config/ad_placement.dart';
export 'src/core/config/ad_unit_ids.dart';
export 'src/core/config/ads_config.dart';
export 'src/core/config/ads_consent_config.dart';
export 'src/core/config/ads_environment.dart';
export 'src/core/config/ads_request_config.dart';
export 'src/ads/banner/banner_ad_config.dart';
export 'src/core/enums/ad_load_status.dart';
export 'src/core/enums/ad_network.dart';
export 'src/core/enums/ad_type.dart';
export 'src/core/events/ads_callbacks.dart';
export 'src/core/events/ads_event.dart';
export 'src/core/events/ads_failure_event.dart';
export 'src/core/events/ads_load_event.dart';
export 'src/core/events/ads_paid_event.dart';
export 'src/core/events/ads_reward_event.dart';
export 'src/core/load/ads_load_notifier.dart' show AdsLoadListener;
export 'src/core/fullscreen/fullscreen_ad_cooldown_config.dart';
export 'src/core/results/ad_failure.dart';
export 'src/core/results/ad_result.dart';
export 'src/domain/repositories/ads_repository.dart';
export 'src/services/ads_service.dart';
export 'src/services/google_ads_service.dart';
export 'src/app_ads.dart';
export 'src/ads/app_open/ads_app_lifecycle_observer.dart';
export 'src/ads/banner/ads_banner.dart';
export 'src/ads/native/ads_collapsible_native.dart';
export 'src/ads/native/ads_full_screen_native.dart';
export 'src/ads/native/ads_native.dart';
export 'src/ads/native/native_ad_close_button.dart';
export 'src/ads/native/native_ad_collapse_button.dart';
export 'src/ads/native/ads_language_start_native.dart';
export 'src/ads/native/native_ad_shimmer.dart';
export 'src/ads/native/native_ad_type.dart';
export 'src/ads/native/native_ad_template.dart';
export 'src/ads/native/native_ad_style.dart';
export 'src/script/ad_script.dart';
export 'src/script/ad_config_enums.dart';
export 'src/script/ad_scenario_coordinator.dart';
export 'src/script/ad_scenario_controller.dart';
export 'src/script/ad_scenario_keys.dart';
export 'src/widgets/core_ad_slot.dart';
export 'src/widgets/ads_loading_widget.dart';

// AdMob's own foreground/background signal, for callers driving App Open ads.
// Unlike [WidgetsBindingObserver] it fires only on a real process
// background/foreground trip, so a status-bar pull or a fullscreen ad taking
// over the Flutter view does not read as a resume.
export 'package:google_mobile_ads/google_mobile_ads.dart'
    show AppState, AppStateEventNotifier;
