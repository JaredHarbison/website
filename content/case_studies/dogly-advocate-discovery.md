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

Dogly's advocate directory needed to serve two different user behaviors. Some users know how they want to browse: location, topic, category, availability, and sort order. Others describe a problem in natural language and expect the product to connect them with someone relevant.

The advocate discovery work introduced both modes without turning the page into a client-side application.

## Problem

A directory is only useful if users can form a mental model of how to search it. Dog owners may think in terms of categories like training or nutrition, but they also think in phrases like "separation anxiety", "red skin", or "new puppy biting".

The existing domain already had advocates, posts, tags, topic profiles, plans, and availability. The challenge was making those relationships usable from a public page.

## Context

The app is server-rendered Rails with Haml views and Stimulus controllers. Search results needed to work through normal Rails requests, remain crawlable, and preserve accessibility.

The page also had to fit a larger partner ecosystem, including public calls to join as a partner.

## Constraints

- Keep the page usable without building a SPA.
- Preserve accessible tab semantics between Browse and Match modes.
- Reuse existing tags, topic profiles, posts, and advocate content.
- Avoid showing hidden or inactive advocates to normal users.
- Support admin visibility when appropriate.
- Make location filtering degrade gracefully when geocoding fails.

## My Role

I worked on the Rails query layer, controller behavior, Haml page structure, Stimulus interaction, and tests around the matching flow.

## Approach

The main design decision was to treat discovery as a query composition problem.

`AdvocateQuery::Base` starts with a base advocate scope and applies filters according to params. Browse mode applies structured filters. Match mode bypasses browse filters and uses free text to find related tags before returning advocates with published content tied to those tags.

The controller stays thin: it prepares topic/channel data for the view, asks the query object for results, and renders HTML or JSON.

## Technical Implementation

Browse mode supports category, channel, topic, location, availability, followed advocates, featured advocates, and sort order.

Match mode uses `TagMatcher` against a bounded text input, then looks for published posts tagged with the matched tags. Advocates are returned through their authored content. This makes the result feel less like a keyword search against profile text and more like a connection to proven topical expertise.

The Stimulus controller handles tab state, keyboard switching, and panel sizing. The form submission remains standard Rails.

## Tradeoffs

Some filters can stay entirely in ActiveRecord. Others rely on domain methods such as top tags or published content relationships and are simpler to express in Ruby. That kept the first version understandable, but it is an area I would optimize if result volume grew.

Match mode depends on tag quality. That is a good fit for a content-heavy product, but it means the search experience is only as strong as the tagging taxonomy.

## Outcome

The directory now supports two user intents:

- Browse by known filters.
- Describe a problem and get matched to relevant advocates.

It also keeps the implementation aligned with the Rails app: server-rendered pages, query objects, focused JavaScript, and accessible controls.

## What I'd Improve Today

I would add query instrumentation and result-quality logging for match searches. That would make it easier to see which phrases fail, which tags are overused, and where the taxonomy needs editorial improvement.

I would also move any remaining array-based filters into database-backed queries where practical.
