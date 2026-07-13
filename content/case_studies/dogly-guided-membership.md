---
title: Turning a Content Library into a Guided Membership
navigation_title: Dogly Guided Membership
summary: Connecting discovery, conversation, personalized email, daily plans, subscriptions, and live expert groups into a membership journey that increased subscriptions by more than 40%.
date: 2026-07-11
role: Software Engineer
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Stripe
  - Zoom
  - React
  - AWS
tags:
  - Rails
  - Product Engineering
  - Growth
  - Commerce
  - Search & Discovery
  - Integrations
status: published
---

## Overview

Dogly had an unusually valuable content base: certified trainers, nutritionists, and wellness specialists publishing practical guidance for dog owners.

Before this work, using that expertise required determination. A visitor browsed an index of Advocates, opened individual profiles, and searched through their content. There was no shared tagging system, no conversation on content, no personalized email program, no daily agenda, and no integrated live-group experience.

The product had experts and information. It did not yet have a guided membership journey.

Over several phases, I helped turn that library into an engagement and membership system: Stripe access levels, tags and topic discovery, comments and replies, personalized Dogly Daily emails, Dogly Helps campaigns for non-members, daily plans, and Zoom groups with Advocates.

Internal pre- and post-work subscription comparisons showed an increase of more than 40%.

![Dogly membership journey before and after](/images/dogly-membership-journey.svg)

## Problem

The original experience placed most of the work on the customer.

A dog owner usually arrives with a problem, not an understanding of Dogly's organizational model. They think, "My dog has separation anxiety" or "I need to improve her diet," not "I should browse the advocate directory and inspect several specialist profiles."

Even after finding useful content, there was little connective tissue:

- No topic model connected related guidance.
- No comments or replies supported follow-up questions.
- No daily plan turned reading into action.
- No lifecycle email brought someone back to the next useful step.
- No integrated live session deepened the relationship with an Advocate.
- Subscription access existed as a business idea, but not yet as a cohesive product journey.

## My Role

I worked across product planning and the full Rails stack, often directly with Dogly's founders and Advocates.

My role included building and evolving subscription state, content access, tagging, comments and replies, notification and digest systems, daily guidance, Zoom meeting workflows, reporting, and the product surfaces connecting them.

The work was incremental. Dogly could not pause its existing community and commerce product for a clean rewrite. Each new capability had to fit a domain already containing users, dogs, Advocates, posts, products, subscriptions, follows, favorites, and notifications.

## Building Discovery Around Problems

Tags gave content a shared vocabulary across Advocates and channels. They supported browsing by topic, related-content paths, digest selection, and eventually the matching and personalized-plan systems.

That taxonomy was more than a filtering feature. It became connective tissue between what a person said they cared about and what Dogly could recommend next.

The tradeoff was governance. Tags created casually by many authors become inconsistent quickly. Normalization, channel relationships, usage thresholds, and editorial cleanup were necessary to keep discovery useful.

## Adding Conversation

Comments and replies turned content from a one-way publication into a place where members could ask questions and Advocates could respond.

The implementation included interaction permissions tied to subscription access, asynchronous updates, author identity, reply notifications, editing and deletion, and counts used throughout cards and community views.

This changed the value of an article. It was no longer only something to consume; it became an entry point into expert support.

## Dogly Daily and Dogly Helps

Email became the most consistent engagement channel.

**Dogly Daily** served members. It selected guidance related to the topics and Advocates they followed, avoided repeating content, and evolved toward a tailored daily plan containing activities a person could complete with their dog.

**Dogly Helps** served non-members. Instead of sending a generic newsletter, it highlighted specific ways Dogly could help and gave the recipient a useful path into expert guidance and membership.

Both systems had to answer more than "what content is newest?" Selection depended on membership state, follows, tags, previous notifications, available content, and the sequence of guidance already shown.

The systems also needed graceful fallbacks. A person with no follows still needed a meaningful email. A category with no unused content could not break the entire digest. A non-member should see enough value to understand the product without receiving member-only guidance as if they already had access.

## Live Expert Groups

Zoom groups gave members another way to use the Advocate network.

Advocates could schedule live sessions from within Dogly. The system created and updated Zoom meetings, registered participants, exposed launch links according to role and time, sent reminders, and connected recordings back to the content experience.

The retained production data includes 77 meeting records, 679 registrations, and 50 posts connected to Zoom meetings. Those numbers are modest compared with a mass webinar product, but meaningful for a specialized expert community: members were choosing to show up and participate.

## Subscription and Compensation Tradeoffs

The product model affected Advocate compensation.

Early in the program, Advocates were expected to bring their own subscribers and therefore received a larger share of those subscriptions. As Dogly's discovery, SEO, email, and guided plans brought more customers directly into the platform, the center of acquisition shifted toward the shared Dogly Advocate plan.

That created a difficult but necessary distinction between attribution and contribution. One Advocate might acquire the customer, several might create the guidance in a plan, and another might answer the question that retained the member.

The software could record subscriptions, follows, content interaction, and participation, but no compensation formula could remove the product and relationship decisions involved. The system needed to preserve useful attribution without pretending it was a complete measure of value.

## Outcome

The work changed Dogly from a directory-led content product into a guided membership experience.

People could discover relevant topics, interact with experts, receive tailored guidance, follow a daily plan, join live groups, and return through lifecycle email. Non-members received a clearer explanation of what membership could do for them; members received a reason to keep using it.

Internal comparisons of subscription levels before and after the engagement work showed growth of more than 40%. Because later Stripe synchronization created historical records in bulk, I treat that percentage as the business measurement made at the time rather than reconstructing false precision from the current database snapshot.

## What I'd Improve Today

I would model the journey as explicit assignments and lifecycle events earlier. Some of the personalization evolved through follows, notifications, digest history, and cached progress. Those pieces work, but a first-class assignment model makes the reason behind each recommendation easier to inspect.

I would also instrument the funnel around meaningful transitions: problem selected, guidance started, first activity completed, question asked, live group attended, trial started, and paid conversion. That would make it easier to distinguish engagement that feels busy from engagement that predicts value.

Finally, I would design compensation reporting alongside the shared-plan model instead of adapting advocate-specific subscription reporting after acquisition behavior changed.
