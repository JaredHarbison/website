---
title: "Karaoke Queue: Built for the Room"
navigation_title: "Karaoke Queue"
summary: Designing a shared, multi-role karaoke queue where performers can participate from their phones while hosts retain control of a live event.
hero_image: /images/karaoke-queue-host-queue.png
hero_alt: Karaoke Queue host workspace showing the live queue with current, next, and upcoming performers.
date: 2026-08-29
order: 8
role: Senior Software Engineer and Product Design Lead
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Hotwire
  - Stimulus
  - YouTube Data API
  - RSpec
tags:
  - Rails
  - Product Engineering
  - Architecture
  - Accessibility
  - Operations
  - Testing
status: published
---

## Overview

Karaoke looks simple from the room: choose a song, wait for your turn, sing, and let the next person go.

The software underneath has to support several people with different needs at the same time. Performers need a fast phone flow. A host needs to manage a live queue without losing the room. A venue owner needs reusable setup and safe delegation. A shared display needs to make the next performance legible from a distance.

Karaoke Queue is a Rails application for that shared experience. It began as a straightforward song queue and has been evolving into a venue- and event-scoped product with contextual roles, recurring events, configurable themes, presence-aware admission, fair ordering, and a presentation surface.

![Karaoke Queue boundaries: performers participate through a venue and live event; the host manages the event; the display presents the current and next songs.](/images/karaoke-queue-room-model.svg)

## Problem

A normal playlist solves the wrong problem. It can collect requests, but it does not answer the operational questions that make a karaoke night work:

- Which venue and event does this request belong to?
- Can this performer add a song right now?
- Who is allowed to advance, postpone, or reorder the queue?
- How does the host avoid one person monopolizing the night?
- What happens when a YouTube video cannot play in an embed?
- How can a permanent printed QR help people find an event without becoming a permanent queue credential?

The product needed to keep those rules out of the performer’s way while making them explicit where the host and venue operator need them.

## Context

The app is server-rendered Rails with PostgreSQL, Haml and ERB views, Sass, Turbo, and small Stimulus controllers. That was intentional. A karaoke night has live interaction, but it does not require a client-side application to render the whole product.

Rails owns authentication, authorization, queue mutations, event lifecycle, and the rendered page. Turbo updates queue state without a frontend framework. Stimulus is reserved for focused browser behavior: YouTube search, the player overlay, responsive controls, dialogs, and queue refresh.

## Constraints

- The performer path had to work on a phone in a busy room, while host and owner workspaces needed desktop information density.
- Venue membership and authority had to be contextual: a host at one venue should not receive that authority elsewhere.
- A permanent venue link needed to remain useful without becoming a permanent credential to submit songs.
- Queue changes needed to be understandable and recoverable during a live event, including when a host temporarily hands off control.
- The product had to stay server-rendered and testable without introducing a client-side application for a small number of focused interactions.

## My Role

I designed and implemented the product model, Rails boundaries, queue and event behavior, responsive presentation surfaces, YouTube integration, accessibility behavior, and focused test coverage.

The work is still in progress. The case study describes shipped foundations and the next operational slices separately rather than treating a roadmap as a finished product.

## Approach

### Designing for One Room, Three Contexts

The most important interaction decision was to stop treating every user as a queue administrator.

A performer’s primary job is to join the right venue, find a karaoke video, add it, and understand what happens next. A host needs live controls and queue state. A venue owner needs membership, event, and configuration tools that should not compete with the live room workflow. The presentation display is its own desktop-oriented surface, not merely a larger host page.

Those contexts share the same domain records, but they should not share the same information density or permissions.

![A performer discovers a live venue and sees its queue status on a mobile phone.](/images/karaoke-queue-performer-discovery.png)

*Discovery gives a performer a clear path into the active event without exposing venue operations.*

![A performer sees the upcoming queue on a mobile phone.](/images/karaoke-queue-performer-mobile-queue.png)

*The performer queue stays focused on who is singing now, who is next, and where the person is in line.*

The product therefore uses contextual `VenueMembership` records for owner, host, and performer roles. A venue slug establishes the tenancy boundary for a request; the controller resolves `Current.venue`, authenticates `Current.user`, authorizes the action in that venue, and scopes queue data accordingly.

```text
/:venue_slug request
    -> resolve Current.venue
    -> authenticate Current.user
    -> authorize venue role and event state
    -> query the venue-scoped queue
    -> render a performer, host, owner, or display surface
```

That boundary makes the product legible in code as well as in the interface. A host at one venue does not accidentally become a host everywhere, and a performer’s request does not leak into another venue’s queue.

## Technical Implementation

### A Queue Is More Than FIFO

A chronological queue is easy to explain and sometimes unfair in practice. Someone who submits five songs early can dominate a shared night while later arrivals wait.

Fair Queue is an event-level option that orders performers by completed turns, then preserves stable queue position and ID tie-breaking. A performer’s additional requests count as later turns during the same pass. Performers with no completed history begin at the same baseline. Hosts can enable or disable the mode for an event, and pause or unpause overrides remain event-scoped.

The queue ordering lives behind `SongQueue::FairOrder` rather than inside the view or controller. That leaves the canonical song record available for the rest of the application and gives the fairness model a named place to evolve.

![A host workspace shows the live queue with current, next, and upcoming performers alongside direct queue controls.](/images/karaoke-queue-host-queue.png)

*Hosts manage the room from an operational queue surface rather than from the owner configuration workspace.*

This is deliberately not an attempt to make a single algorithm resolve every social decision. Duets, skips, late arrivals, and more configurable fairness models remain future product decisions. The initial rule is useful because it is understandable, event-scoped, and testable.

### Event Boundaries Instead of Permanent Access

Venue access and event access solve different problems.

A permanent venue QR is useful as a durable wayfinding tool. It should not act as a reusable credential to submit songs indefinitely. The event model therefore separates an `Event` from an `EventSeries`: a recurring series provides scheduling, while each occurrence has its own title, timing, lifecycle, queue state, and exceptions.

During a live event, a performer establishes an expiring event-presence session. The intended admission policy combines authenticated identity, a live event, and an active presence session. Attempts are rate-limited and operational telemetry is retained only briefly. The static QR remains stable while the authority to queue is time-bounded.

```text
Permanent venue QR -> venue / active event -> event code or check-in
                                           -> expiring presence session
                                           -> live-event queue admission
```

That distinction protects the operational boundary without making scanning the only path. A changing code or QR needs an accessibility fallback for people who cannot scan it or read it reliably.

![The owner event workspace shows live status, event details, fair-queue configuration, and a queue cutoff decision.](/images/karaoke-queue-owner-overview.png)

*Owner controls begin with the event state and the operating rules that affect the room.*

![The performer-access section shows a rotating event code, its expiry, and the active theme.](/images/karaoke-queue-owner-access.png)

*Rotating the code revokes the old credential; open queue, presentation, and owner clients refresh to the shared current state.*

### Searching and Selecting Video Without Making a Carousel a Trap

Performers search YouTube from the song form, see karaoke-video results, select one, and submit the request. `YoutubeService` keeps provider search and validation outside the controller, while a small Stimulus controller manages the request lifecycle and result selection.

The result rail is intentionally horizontal on constrained screens, but horizontal scrolling alone is not an accessible interaction. Touch swiping and a visible scrollbar do not help every keyboard or switch user.

When the result rail overflows, it exposes labelled previous and next buttons. The controls are disabled at their respective ends, identify the result region with `aria-controls`, and scroll a predictable portion of the rail. Result cards use a real selection button; decorative thumbnails have empty alternative text; and the rail itself is a named focusable region.

The implementation also cancels superseded searches, keeps the search button state coherent, escapes provider-returned values before rendering them, and keeps selection as a normal form submission rather than a hidden client-side state transition.

![A performer searches for Tears in Heaven and selects a karaoke video from the result rail.](/images/karaoke-queue-song-search.png)

*Search results use explicit selection controls and keyboard-operable result-rail navigation.*

### Keeping the Live Queue Honest

The queue has to behave safely when the room is busy, not just when one person is clicking through a happy path.

The event admission work models the projected runtime as video duration plus a transition buffer. It prefers provider duration when available, falls back to the event’s known-duration average when necessary, and uses a safe default when there is no history. If accepting a request would push the event past its planned end, admission stops unless a host or owner has made an auditable overrun decision.

The event row is locked while runtime and insertion checks run, and a client-held submission token makes a retry resolve to its original request rather than duplicating it. This is a practical concurrency boundary around a problem that becomes real as soon as several people submit at once.

The player is equally defensive. It uses YouTube’s iframe API for the host and presentation experiences, records start and finish actions, advances state deliberately, and gives the host a clear recovery path if a video owner has disabled embedded playback.

![Presentation mode shows the active karaoke video, event access code, and the next two performers.](/images/karaoke-queue-presentation.png)

*The display is a dedicated in-room surface, not simply a scaled-up host view.*

### Time-Bounded Delegation and Auditable Overrides

Venue owners can apply a theme for an entire event or a bounded window, delegate host authority to an eligible member for a bounded window, and revoke that authority when it is no longer needed. Management-facing screens use full names to distinguish similarly named people, while performer-facing queue identity remains abbreviated.

![The owner workspace shows theme application, delegated-host controls, and an active temporary host with a revoke action.](/images/karaoke-queue-owner-delegation.png)

*Temporary authority is explicit, time-bounded, and removable rather than implied by a shared login.*

Fair Queue allows a host to intervene when the room needs it, but the intervention records the action, performer, actor, and timestamp.

![A recent fair queue override records a pause action with the performer, acting host, and timestamp.](/images/karaoke-queue-owner-fair-overrides.png)

*The audit trail keeps an operational override explainable after a busy night.*

## Tradeoffs

The app deliberately preserves some transitional structure while the product model becomes more event-centered. Existing venue-level songs remain supported while event-scoped queueing is established. The legacy global admin role and `VenueAdmin` join model remain compatibility foundations rather than the final permissions model.

The first fairness model favors an explicit rule over a configurable system. Presence is a bounded signal rather than perfect proof of physical attendance. YouTube is a pragmatic provider boundary, but its availability and embed rules remain outside the app’s control.

Those are not reasons to postpone a useful first product. They are boundaries worth naming so that later work strengthens the right layer instead of adding another conditional to a controller or template.

## Outcome

Karaoke Queue now has the foundations for a multi-venue, role-aware karaoke product: venue-scoped routes and authorization, owner/host/performer roles, YouTube search and validation, a managed queue, host playback, a presentation surface, recurring event foundations, theme foundations, and focused system and request coverage.

The enduring result is a product model that treats a karaoke night as a live event with different participants, not just a list of songs. The same boundaries support a performer using a phone in a crowded room, a host advancing the queue, and a venue operating recurring nights.

## What I'd Improve Today

I would finish the transition from the legacy `Song` queue record to a dedicated canonical `Performance` model. That would make event lifecycle, provider state, duration, audit history, and queue semantics more explicit.

I would add observable queue instrumentation: search success, selected video, admitted request, rejection reason, queue wait estimate, performance started, performance completed, and host overrides. That would show where performers leave the flow and whether Fair Queue improves participation.

I would also complete a full accessibility review with keyboard and assistive-technology testing at the performer, host, and presentation surfaces. The result-rail controls are one concrete example; live-region behavior, focus return from player dialogs, color contrast, error handling, and non-QR event entry need the same product-level rigor.
