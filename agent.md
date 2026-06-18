# Flutter Ads Package - Project Specification

## Project Overview

Build a reusable Flutter package for mobile advertising.

This package is intended to be shared across multiple Flutter applications, including:

* Live Wallpaper
* Time Warp Scan
* Color By Number
* Future mobile applications

The package must be independent from any application and follow Clean Architecture.

---

# Main Goals

* Reusable
* Scalable
* Production Ready
* Easy to maintain
* Easy to add new Ad Networks
* Easy to migrate from AdMob to Mediation
* Platform independent (Android & iOS)

The package should expose a very simple public API while hiding all SDK implementations.

---

# Development Rules

## DO

* Follow Clean Architecture.
* Follow SOLID principles.
* Use Dependency Injection.
* Separate interface and implementation.
* Prefer composition over inheritance.
* Write readable code.
* Add Dart documentation for every public class.
* Keep classes small and focused.
* Avoid singleton unless there is a good reason.
* Managers may internally use singleton if lifecycle requires it.

## DON'T

* Don't call Google Mobile Ads directly from UI.
* Don't hardcode Ad Unit IDs.
* Don't mix business logic with SDK implementation.
* Don't put everything into one class.
* Don't expose Google SDK classes in public API.
* Don't create unnecessary abstractions.

---

# Architecture

packages/

flutter_ads_core/

* interfaces
* models
* enums
* exceptions
* results

flutter_ads_google/

* google implementation
* google managers
* google services

flutter_ads/

* public API
* widgets
* exports

The final application only depends on flutter_ads.

---

# Public API

The application should only interact with:

```dart
FlutterAds.initialize();

FlutterAds.showInterstitial();

FlutterAds.showReward();

FlutterAds.showAppOpen();

FlutterAds.banner();

FlutterAds.dispose();
```

The application must never know which SDK is being used internally.

---

# Layers

## Domain

Contains:

* Repository interfaces
* Models
* Enums
* Value Objects
* Result classes

No SDK imports.

---

## Data

Contains:

* Repository implementation

Repository communicates with Managers only.

---

## Managers

Managers are responsible for ad lifecycle.

Required managers:

* ConsentManager
* BannerManager
* InterstitialManager
* RewardManager
* NativeManager
* AppOpenManager

Each manager should have a single responsibility.

---

## Services

Services communicate with SDK.

Initially implement:

GoogleAdsService

Later:

* AppLovinService
* UnityAdsService
* IronSourceService

Managers communicate with Services instead of SDK directly whenever possible.

---

## Config

Contains:

AdsConfig

Ad IDs

Environment

Debug configuration

Test IDs

Production IDs

No hardcoded values anywhere else.

---

## Consent

Implement Google UMP.

Responsibilities:

* Request consent
* Cache consent state
* Determine whether ads can be requested
* Support future privacy updates

---

# Supported Ad Types

Banner

Interstitial

Rewarded

Rewarded Interstitial

Native

App Open

Each ad type should have an isolated manager.

---

# Interstitial Flow

Application starts

↓

Initialize SDK

↓

Load Ad

↓

Ad Ready

↓

Show

↓

Dispose

↓

Load New Ad

Never load when user clicks unless preload failed.

---

# Reward Flow

Load

↓

Ready

↓

Show

↓

Wait for callback

↓

Reward User

↓

Dispose

↓

Load New

Reward must only be granted inside onUserEarnedReward.

---

# Banner Flow

Banner should be cached.

Avoid loading every page.

Reuse BannerAd whenever possible.

---

# App Open Flow

Load

↓

Cache

↓

Application Resume

↓

Check Expiration

↓

Show

↓

Load New

Expired ads must never be shown.

---

# Frequency Controller

The package should include an AdFrequencyController.

Example responsibilities:

* show every N actions
* cooldown between ads
* avoid spam
* configurable

Example:

5 button clicks

↓

Show Interstitial

---

# Error Handling

Never crash because of Ads.

Return Result objects when possible.

Example:

Success

Failed

NoFill

NetworkError

NotReady

ConsentDenied

---

# Logging

Provide internal logger.

Debug only.

Example:

[Ads]

Interstitial Loaded

Banner Failed

Reward Granted

App Open Expired

---

# Dependency Injection

Use constructor injection.

Avoid service locator inside package logic.

The application can choose its own DI framework.

The package should not depend on injectable/get_it.

---

# Widgets

Provide reusable widgets.

Example:

AdsBanner()

RewardButton()

NativeAdWidget()

Widgets must hide SDK implementation.

---

# Testing

Unit tests are required for:

Frequency Controller

Repository

Consent Manager

Config

Result mapping

Business logic should be testable without Google SDK.

---

# Coding Style

Use immutable models whenever possible.

Prefer final.

Avoid static except public facade.

Prefer async/await.

Keep files under approximately 300 lines if possible.

Avoid deeply nested code.

Document public APIs.

---

# Future Roadmap

Phase 1

* flutter_ads_core
* flutter_ads_google

Phase 2

* UMP
* Banner
* Interstitial
* Reward

Phase 3

* Native
* App Open

Phase 4

* Mediation support

Phase 5

* AppLovin


Phase 6

* Analytics hooks

* Revenue callbacks

* Impression callbacks

* Remote Config integration

---

# How Codex Should Work

Do NOT generate the entire package at once.

Work incrementally.

Each milestone should include:

1. Design explanation
2. Folder structure
3. Implementation
4. Example usage
5. Review of design decisions

Wait for confirmation before continuing to the next milestone.

Always prefer maintainability over writing the shortest code.

If a design decision has multiple valid approaches, explain the trade-offs before implementing.

Act as a senior Flutter architect reviewing production-quality code, not as a code generator.
