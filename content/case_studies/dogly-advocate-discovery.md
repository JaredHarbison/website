---
title: Dogly Advocate Discovery
summary: Designing browse and match modes for finding the right professional in a content-rich Rails application.
date: 2026-07-07
role: Senior Software Engineer
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Stimulus
  - Geocoder
  - RSpec
tags:
  - Rails
  - Product Engineering
  - Search & Discovery
  - Architecture
  - Testing
status: published
---

## Overview

Dogly's advocate directory needed to serve two different user behaviors. Some users know how they want to browse: location, topic, category, availability, and sort order. Others describe a problem in their own words and expect the product to connect them with someone relevant.

The advocate discovery work introduced both modes without turning the page into a client-side application.

## Problem

A directory is only useful if users can form a mental model of how to search it. Dog owners may think in terms of categories like training or nutrition, but they also think in phrases like "separation anxiety", "red skin", or "new puppy biting".

The existing domain already had advocates, posts, tags, topic profiles, plans, and availability. The challenge was making those relationships usable from a public page.

## Context

The app is server-rendered Rails with Haml views and Stimulus controllers. Search results needed to work through normal Rails requests and remain crawlable. The Browse/Match control follows ARIA tab semantics and supports arrow, Home, and End keyboard navigation.

The page also had to fit a larger partner ecosystem, including public calls to join as a partner.

## Constraints

- Keep the page usable without building a SPA.
- Preserve accessible tab semantics between Browse and Match modes.
- Reuse existing tags, topic profiles, posts, and advocate content.
- Avoid showing hidden or inactive advocates to normal users.
- Support admin visibility when appropriate.
- Make location filtering degrade gracefully when geocoding fails.

## My Role

As Dogly's sole engineer, I designed and implemented the Rails query layer, controller integration, Haml page structure, Stimulus interactions, and focused tests around matching and visibility.

## Approach

The main design decision was to give discovery an explicit query boundary rather than distribute filtering and visibility rules across the controller and view.

`AdvocateQuery::Base` starts with a base advocate scope and applies filters according to params. Browse mode applies structured filters. Match mode bypasses browse filters and uses free text to find related tags before returning advocates with published content tied to those tags.

Filtering and visibility rules stay outside the controller. The controller coordinates the query, prepares the channel/topic datasets required by the view, and renders HTML or JSON.

## Technical Implementation

Browse mode supports category, channel, topic, location, availability, followed advocates, featured advocates, and sort order.

Match mode is taxonomy-backed lexical matching rather than semantic or AI search. `TagMatcher` tokenizes a bounded text input, matches individual words and adjacent two-word phrases against curated tags and problem vocabulary, then looks for Advocates with published content connected to those tags. This makes the result less like a keyword search against profile text and more like a connection to demonstrated topical expertise.

The Stimulus controller handles tab state, keyboard switching, and panel sizing. The form submission remains standard Rails.

## Extending the Directory Pattern

The Advocate directory became the most sophisticated version of a shared partner-directory pattern. Brands and shelters later received their own query objects, responsive directory pages, configurable imagery, and filters appropriate to their domains. A shared `Partners::DirectoryController` coordinates the three directory experiences without pretending their discovery rules are identical.

Free-text expertise matching remains Advocate-specific. Brand discovery is organized around commerce categories and products, while shelter discovery is organized around location and other shelter-specific attributes.

## Tradeoffs

Some filters remain ActiveRecord relations. Tag and topic filters rely on domain methods and can materialize results into Ruby arrays. That kept the first version understandable, but it also complicates filters and sorting that run afterward in addition to increasing memory use. A stronger version would express every filter as a relation or explicitly separate the database and in-memory query phases.

Match mode depends on tag quality. That is a good fit for a content-heavy product, but it means the search experience is only as strong as the tagging taxonomy.

## Outcome

The shipped directory supports two user intents:

- Browse by known filters.
- Describe a problem and get matched to relevant advocates.

It also keeps the implementation aligned with the Rails app: server-rendered pages, an explicit query boundary, focused JavaScript, and concrete keyboard behavior.

We did not yet have result-quality instrumentation capable of showing whether matching improved successful connections between dog owners and Advocates. The outcome is therefore a shipped product capability, not a claim of measured conversion improvement.

## What I'd Improve Today

I would add query instrumentation and result-quality logging for match searches. That would make it easier to see which phrases fail, which tags are overused, and whether a result leads to a profile view, question, booking, or subscription.

I would move the remaining array-based filters into database-backed queries where practical, preserving an ActiveRecord relation throughout the query pipeline.

I would also replace the broad `Post.unscoped` match lookup with an explicit discovery scope containing published, visible, non-deleted content. Visibility rules should be named and testable rather than reconstructed through a partial set of conditions.
