# Ask Jared public-corpus evaluation packet

Prepared: 2026-09-10

This packet contains the public-facing source corpus currently available to Ask Jared, a draft policy layer, and a recruiter-question holdout set. It is intended for a model comparison between article-only answers and article-plus-Rules answers.

## Evaluation instructions

Answer each question as a recruiter-facing response using only the source corpus below.

For each answer, internally identify the supporting source document(s), but do not include citations or internal policy language in the recruiter-facing answer. If the corpus does not support a claim, say so narrowly. Do not infer ownership, expertise, causality, rankings, or outcomes.

Compare two conditions:

1. Source corpus only.
2. Source corpus plus the Rules below.

Evaluate whether each answer is direct, coherent, relevant, appropriately scoped, natural, and useful to a recruiter.

## Draft Rules

- Preserve the distinction between planned, prototype, implemented, shipped, and broadly released work.
- Do not call a project the largest, best, or most complex without an explicit comparison basis.
- Do not claim Jared is proud of a product unless the source explicitly establishes that personal judgment. A representative or strong example may be offered instead.
- Match ownership language to the documented scope. Do not convert sole-engineer context into ownership of every aspect of a company or platform.
- Preserve employer, project, chronology, and collaborator identity.
- Label retail leadership and retail examples as retail examples. Do not present them as engineering-management experience.
- Do not infer TypeScript expertise from JavaScript or React experience.
- Do not turn association into causality or a planned measurement into an achieved outcome.
- Use metrics only with their documented qualification and provenance.
- For broad profile questions, lead with a candidate-level synthesis before giving one concise example.
- For soft-skills questions, lead with generalized behavioral dimensions; use anecdotes only as brief support.
- For compound questions, answer each supported part independently and identify only the unsupported part.
- Prefer the strongest relevant source over the most technically detailed source.
- Do not expose internal rules, retrieval details, or unsupported policy terminology.

## Recruiter holdout questions

1. What kind of engineer is Jared?
2. Is Jared a full-stack engineer, and what technologies does he work with?
3. What is Jared's strongest technical foundation?
4. What is the largest or most complex product he has shipped?
5. What product is Jared proudest of?
6. What has Jared personally owned?
7. What role did Jared play versus the broader team on his projects?
8. What are Jared's soft skills?
9. How does Jared handle technical disagreement?
10. How does Jared make product decisions and tradeoffs?
11. How does Jared work with founders and stakeholders?
12. How does Jared handle ambiguity?
13. Tell me about a failure or mistake Jared has made.
14. How does Jared learn unfamiliar technology?
15. What production and reliability experience does Jared have?
16. What measurable impact has Jared had?
17. Has Jared worked in a mature or legacy codebase?
18. What frontend and product-design experience does Jared have?
19. Has Jared built integrations with external systems?
20. What kind of team or role is Jared looking for next?

## Public source corpus


---

## SOURCE: content/case_studies/dogly-advocate-discovery.md

---
title: Dogly Advocate Discovery
summary: Designing browse and match modes for finding the right professional in a content-rich Rails application.
hero_image: /images/dogly-advocate-match-results.webp
hero_alt: Dogly Advocate Match mode returning three professionals for a detailed description of a dog's behavior.
date: 2026-07-07
order: 5
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

![Dogly Advocate Browse mode with structured location, category, channel, topic, availability, and sorting controls](/images/dogly-advocate-browse-filters.webp)

*Browse mode supports people who already know how they want to narrow the professional directory.*

Match mode is taxonomy-backed lexical matching rather than semantic or AI search. `TagMatcher` tokenizes a bounded text input, matches individual words and adjacent two-word phrases against curated tags and problem vocabulary, then looks for Advocates with published content connected to those tags. This makes the result less like a keyword search against profile text and more like a connection to demonstrated topical expertise.

The Stimulus controller handles tab state, keyboard switching, and panel sizing. The form submission remains standard Rails.

![Dogly Advocate Match mode in a narrow mobile layout with one professional result](/images/dogly-advocate-match-mobile.webp)

*The same matching workflow collapses into a focused single-column layout at mobile widths.*

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


---

## SOURCE: content/case_studies/dogly-membership.md

---
title: Dogly Membership Experience
summary: Connecting discovery, conversation, personalized email, daily plans, subscriptions, and live expert groups into a membership journey associated with more than 40% subscription growth in internal comparisons.
hero_image: /images/dogly-membership-journey.svg
hero_alt: Diagram showing the Dogly membership journey before and after.
date: 2026-07-11
order: 2
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

## Context

This was an incremental change inside a mature Rails application. The existing domain already connected users, dogs, Advocates, posts, products, subscriptions, follows, favorites, notifications, and live meetings, so each new capability had to extend those relationships without interrupting the existing community and commerce experience.

## Constraints

- Add value across discovery, engagement, and membership without requiring a rewrite.
- Keep access and messaging correct for members and non-members.
- Make recommendations useful for people with different dogs, follows, and levels of progress.
- Preserve operational visibility for email delivery, content reuse, live groups, and Advocate attribution.

## My Role

I worked across product planning and the full Rails stack, often directly with Dogly's founders and Advocates.

My role included building and evolving subscription state, content access, tagging, comments and replies, notification and digest systems, daily guidance, Zoom meeting workflows, reporting, and the product surfaces connecting them.

The work was incremental. Dogly could not pause its existing community and commerce product for a clean rewrite. Each new capability had to fit a domain already containing users, dogs, Advocates, posts, products, subscriptions, follows, favorites, and notifications.

## Approach

The product was built as a connected sequence of small systems: establish a topic vocabulary, add conversation, use that context to select guidance, turn guidance into a daily plan, and create return paths through email and live groups. Each step reused the records and permissions already present in Dogly.

## Technical Implementation

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

**Dogly Daily** served members. It selected guidance related to the topics and Advocates they followed, avoided repeating content, and evolved toward a tailored daily plan containing activities a person could complete with their dog. The current delivery path is dog-scoped: a member receives a plan only for a dog with its own followed topics, and delivery history, notifications, progression, and completion state stay associated with that dog rather than being shared across the account.

**Dogly Helps** served non-members. Instead of sending a generic newsletter, it highlighted specific ways Dogly could help and gave the recipient a useful path into expert guidance and membership.

Both systems had to answer more than "what content is newest?" Selection depended on membership state, follows, tags, previous notifications, available content, and the sequence of guidance already shown. The latest member-email flow also records successful delivery before advancing the dog’s sequence, supports staged first, reminder, and final-reminder sends, and lets recipients complete or skip work from the email through signed, expiring action links.

The systems also needed graceful fallbacks. A person with no follows still needed a meaningful email. A category with no unused content could not break the entire digest. A non-member should see enough value to understand the product without receiving member-only guidance as if they already had access.

## Live Expert Groups

Zoom groups gave members another way to use the Advocate network.

Advocates could schedule live sessions from within Dogly. The system created and updated Zoom meetings, registered participants, exposed launch links according to role and time, sent reminders, and connected recordings back to the content experience.

The retained production data includes 77 meeting records, 679 registrations, and 50 posts connected to Zoom meetings. Those numbers are modest compared with a mass webinar product, but meaningful for a specialized expert community: members were choosing to show up and participate.

## Tradeoffs

### Subscription and Compensation

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


---

## SOURCE: content/case_studies/dogly-partner-applications.md

---
title: Dogly Partner Applications
summary: Designing a resumable partner application and transparent review workflow inside a mature Rails marketplace without forcing a platform rewrite.
hero_image: /images/dogly-partner-application-flow.svg
hero_alt: Diagram showing a partner application that progressively reveals profile, details, branding, and final authorization steps.
date: 2026-07-08
order: 4
role: Senior Software Engineer
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Stimulus
  - Haml
  - SCSS
  - RSpec
tags:
  - Rails
  - Product Engineering
  - Onboarding
  - Legacy Systems
  - Testing
status: published
---

## Overview

Dogly is a Rails marketplace and community product connecting dog owners with professional advocates, brands, and shelters. The codebase has years of accumulated product surface: ecommerce, community content, subscriptions, advocate profiles, admin tools, reporting, and partner management.

Partner Pro established shared entry points for Dogly's partner ecosystem, while its guided application and review lifecycle was first implemented for Advocates. The work covered resumable onboarding, application details, admin review, and applicant-visible revisions.

The important engineering challenge was not just adding screens. It was introducing a new product flow into a mature Rails application without destabilizing the existing routes, models, and operational assumptions.

## Problem

Dogly needed a clearer path for professionals to apply and a more transparent way to review those applications.

The previous system had the underlying data concepts, but the experience was fragmented:

- Partner applications existed, but did not fully support a guided, resumable onboarding flow.
- Admin review needed better structure around edits, approval, and applicant-facing feedback.
- Credentials and certifications needed to support both existing options and applicant-submitted entries.
- Public pages for advocates, brands, and shelters needed to share patterns without becoming copy-pasted implementations.

The business need was to reduce friction in partner acquisition while improving trust in the review process.

## Context

This was not a greenfield app. Dogly is an older Rails application with existing conventions, a large route file, Haml views, SCSS page styles, RSpec coverage, Solidus-related commerce concepts, and domain models that had evolved over time.

That context shaped the approach. The safest path was to extend Rails conventions already present in the app: controllers, service objects, query objects, Haml partials, model methods, and focused specs.

The work also had to coexist with existing advocate routes. Partner application routes needed to sit before broad advocate slug routes so onboarding URLs were interpreted correctly.

## Constraints

The main constraints were architectural and product-related:

- Avoid a wholesale rewrite of the partner system.
- Preserve existing public advocate pages and admin workflows.
- Keep controllers understandable despite multi-step onboarding.
- Let anonymous applicants resume draft progress through an expiring, unguessable session token stored in an HTTP-only cookie, while still associating applications with users when available.
- Handle geocoding gracefully when a typed location or browser coordinates were available.
- Avoid overwriting saved application data with blank autosave payloads.
- Make admin edits visible to applicants without exposing internal implementation details.
- Keep the multi-step flow responsive and keyboard usable.

There was also a content-management constraint: many public-facing page sections used configurable copy and images, so the implementation needed to fit that system rather than hard-coding every page.

## My Role

I worked across the Rails stack:

- Designed and implemented the Partner Pro onboarding flow.
- Built the application session manager around JSON-backed step data.
- Added admin review behavior, revision tracking, and applicant-facing review states.
- Connected credentials and applicant-submitted certifications into the application process.
- Established shared partner entry points and directory patterns for advocates, brands, and shelters.
- Wrote focused specs around controller behavior, revision diffs, helpers, and the application lifecycle.

The work was product-minded: every technical choice had to support a clearer application and review experience, not just a cleaner code structure.

## Approach

I separated the work into a few durable boundaries.

First, the onboarding flow became session-based. A `PartnerApplicationSession` stores the current step, a secure token, expiration, completion state, and accumulated JSON data. A small `Partners::ApplicationSessionManager` owns the mechanics of creating sessions, saving steps, merging autosave data, exposing the token, and completing the session.

Second, the final persisted `PartnerApplication` remains the durable business record. The session is a draft workspace; the application is the submitted artifact.

Third, admin review became explicit. Admin edits can move an application into review, record a revision log, and show applicants what changed in a review-oriented version of the same onboarding UI.

## Technical Implementation

The onboarding controller handles a small set of explicit steps: profile, details, branding, and payment.

Profile data captures identity, handle, category, location, and coordinates. If browser coordinates are present, the flow can reverse-geocode into a readable location. If the user typed a location and coordinates are missing, it attempts forward geocoding. If geocoding fails, the flow keeps the user-entered value rather than blocking progress.

![The Profile step progressively collects identity, contact, handle, and location information.](/images/dogly-partner-pro-profile.webp)

Details data captures the applicant's legal name and order-integration method, including the fulfillment information needed to route the application correctly.

Branding data captures images (avatar, banner, and mission) and social/profile URLs. The final step records terms acceptance and authorizes Shopify and Stripe connections. On final submission, the controller maps the session data into a `PartnerApplication`, sends the submitted email, completes the session, and shows a submitted/review state.

![The Branding step previews uploaded profile and banner imagery within the guided flow.](/images/dogly-partner-pro-branding.webp)

Autosave is deliberately conservative. Blank values and empty arrays are rejected before merging, so a partial browser event does not erase previously saved data. The tradeoff is that intentionally clearing a saved value needs an explicit action rather than relying on the same merge behavior.

For review, admin updates compare a snapshot of application attributes before and after save. `PartnerApplicationRevision.diff` categorizes tracked changes by section and kind: profile, expertise, and branding; text, image, or multi-select. The applicant review page then shows original answers alongside Dogly edits in the relevant step.

Stimulus handles focused enhancements such as progressive questions, location choices, image-upload state, and autosave. Rails remains the source of truth for validation and persistence.

Partner Pro also established shared directory architecture for advocates, brands, and shelters. The specialized browse and match experience is covered separately in [Dogly Advocate Discovery](/case-studies/dogly-advocate-discovery).

## Tradeoffs

The biggest tradeoff was choosing incremental architecture over a new subsystem.

A fully separate onboarding engine might have been cleaner in isolation, but it would have added routing, deployment, authentication, and data integration overhead. Keeping the work inside the Rails app let the flow reuse existing users, credentials, advocates, copy configuration, image configuration, mailers, and admin patterns.

Storing in-progress application data as JSON made the multi-step form easier to evolve. The tradeoff is that field names and shape require discipline. The final `PartnerApplication` remains the canonical record, so the JSON session is treated as temporary state rather than the business source of truth.

The review page currently computes some applicant-facing differences from original session data versus current application attributes. That makes the UI resilient when revision history is incomplete, but it also means the view knows more about field-level comparison than I would want long term.

## Outcome

The result is a more coherent partner lifecycle:

- Applicants can start, resume, autosave, and submit a guided application.
- Admins can review, edit, approve, and present changes back to applicants for review.
- Applicant-facing review pages show what changed instead of leaving edits opaque.
- Credentials and applicant-requested certifications fit into the same review path.
- Public partner pages share a directory controller pattern across advocates, brands, and shelters.

The work also left behind better internal boundaries: a session manager, revision model, reusable Haml partials, and focused specs.

## What I'd Improve Today

I would move more of the applicant review comparison out of Haml and into a presenter or view model. The current implementation is readable once you know the flow, but the view carries too much field-mapping responsibility.

I would also formalize the shape of session data. A small schema object per step would make autosave, validation, final submission, and review diffs easier to reason about, including an explicit way to clear a previously saved answer.

For applications associated with an account, I would add explicit ownership checks and stop treating the resume token as the sole authorization boundary after submission. I would also stage applicant-proposed certifications on the application and promote them to canonical credentials during review, rather than creating credential records during the expertise step.

Geocoding failures currently fall back gracefully, but I would narrow the rescued exception types and add structured logging so operational failures remain observable.

Finally, I would add a stronger end-to-end test around the full applicant lifecycle: start application, autosave, submit, admin edit, applicant review, and approval.


---

## SOURCE: content/case_studies/dogly-product-design.md

---
title: Dogly Product Design
summary: Building a coherent, image-led product language across six years of expert content, community, subscriptions, onboarding, daily guidance, and commerce.
hero_image: /images/dogly-design-homepage-member.webp
hero_alt: Dogly member homepage combining personalized guidance, content, and expert support.
date: 2026-07-11
order: 1
role: Senior Software Engineer and Product Design Lead
technologies:
  - Figma
  - Ruby on Rails
  - Haml
  - SCSS
  - Stimulus
  - React
tags:
  - Product Engineering
  - Leadership
  - Architecture
  - Operations
status: published
---

## Overview

Over six years at Dogly, I have led much of the product's aesthetic and interaction evolution while also engineering the systems underneath it.

Dogly is not one simple product surface. It combines expert content, community discussion, personalized plans, subscriptions, live groups, ecommerce, partner directories, onboarding, and administrative tools. Each area accumulated its own history, frameworks, and visual conventions.

The design challenge was to make those experiences feel like one product without flattening the emotional quality that users valued most.

## Problem

In a round of customer feedback, users repeatedly told us that they loved Dogly's imagery.

That mattered because images were also one of the site's largest performance costs. The simplest optimization would have been to remove them, reduce them aggressively, or replace them with a more minimal interface.

I did not think that would improve the product.

A small performance improvement may be imperceptible to most people. Removing the images that made the experience feel warm, credible, and inspiring would be immediately visible. The requirement was therefore not "use fewer images." It was "preserve the emotional value of imagery while controlling its cost and keeping text usable."

That principle shaped the visual system that followed.

![Timeline of Dogly's design evolution](/images/dogly-design-evolution.svg)

## Context

This work happened inside a mature Rails product rather than a greenfield design system. The same visual language had to work across public content, member workflows, commerce, partner onboarding, and operational tools, while older surfaces still needed to remain usable.

## Constraints

- Preserve the warmth and credibility that imagery gave Dogly.
- Keep text, controls, and content hierarchy usable across desktop, tablet, and mobile widths.
- Improve consistency without forcing every surface into one identical composition.
- Work within existing Rails, Haml, SCSS, and image-management conventions.

## My Role

I led the product design direction and implemented many of the resulting surfaces across the Rails stack. I worked with founders and domain owners to connect customer feedback, visual decisions, responsive behavior, and the underlying product constraints.

## Approach

### Establishing a Visual Language

I retained the green from Dogly's logo as a selective, consistent brand color. It could communicate trust, continuity, progress, and positive state without saturating every screen.

I introduced orange as the primary interaction color for calls to action, links, frontend actions, and meaningful state changes. This created a clearer distinction between the brand's visual identity and the places where a person could do something.

Imagery also gained a method rather than being selected page by page:

- Grass and dogs in grass for training.
- Concrete and grounded surfaces for nutrition.
- Sky and open atmosphere for wellness.

Those environments were not literal rules for every asset. They gave each content channel a recognizable mood connected to its subject matter.

Layers and overlays protected text contrast when copy sat over photography. Rounded cards, restrained shadows, consistent internal spacing, and repeated content structures helped image-rich pages feel intentional rather than collage-like.

## Technical Implementation

The visual system became concrete through reusable image treatments, typography and spacing decisions, responsive compositions, content-card patterns, and state treatments shared across the product. The following eras show how those decisions were applied rather than presenting a single redesign as if the product had changed all at once.

### Era One: Advocate Profiles

The Advocate show page was my first major Dogly project in 2020.

It needed to communicate professional credibility, expertise, content, and personality on one landing page. That work introduced patterns for image-led headers, Advocate identity, topic presentation, and content cards that influenced later community surfaces.

The page is now one of the older remaining experiences and is due for another modernization. That makes it a useful bookend: it shows both the beginning of the design direction and how far the surrounding system has evolved.

![The 2020 Advocate profile combines professional identity, photography, specialties, and support-group content.](/images/dogly-design-advocate-profile.webp)

*The early Advocate profile established an image-led presentation for professional identity and expertise, but its dense overlay and small controls also show where the system began.*

### Era Two: Channels

The channel system developed from late 2020 and expanded substantially through 2021 and 2022.

Channels organized training, nutrition, and wellness content around topics users understood. They became the clearest early expression of the environmental image language: category photography, layered headers, editorial content, video, recipes, and agendas organized into a consistent page structure.

![The Manners channel uses training photography, a layered header, topic context, and Advocate identity.](/images/dogly-design-channels-hero.webp)

*Channels connected subject matter to a distinct visual environment while keeping the people behind the guidance visible.*

This era also exposed the cost of inconsistency. Similar cards and controls had been implemented in multiple React and Rails surfaces with slightly different spacing, behavior, and responsive assumptions. The product needed reusable decisions, not another isolated page redesign.

![A channel guide combines video, explanatory copy, progress controls, and related content in one learning surface.](/images/dogly-design-channels-guide.webp)

*The guide experience brought media, instruction, navigation, and topic discovery into a repeatable learning structure.*

### Era Three: Onboarding and Daily Guidance

The recent onboarding and `/my-dogly/today` agenda moved the product from browsing into guided action.

Onboarding used a conversational flow, progressive questions, category and topic selection, carefully timed content, and responsive layouts that protected focus on smaller screens. The agenda reused that language for daily tasks, notes, help, progress, recap, and subscription gating.

![A desktop daily guide presents progress context, an expanded task, notes, help, skipping, and completion controls.](/images/dogly-design-today-desktop.webp)

*Daily guidance translated a broad content library into a specific task, with progress and support kept in the same working context.*

These screens required more than desktop and mobile styles. Tablet widths often created their own composition problems: a dog image that supported the experience on desktop could crowd the conversation at 700 pixels; a control that fit on mobile and desktop could wrap awkwardly between them.

I introduced and centralized breakpoints around the actual behavior of components. For highly specific interactions, an additional breakpoint was preferable to forcing a generic two-layout rule onto a screen where it did not work.

![The same daily-guide system reorganized for a narrow mobile viewport.](/images/dogly-design-today-mobile.webp)

*The mobile layout preserved the task, progress, and completion path instead of merely shrinking the desktop composition.*

### Era Four: The Homepage as a System

The 2026 homepage is the strongest expression of the current direction.

It is not one static homepage. Visitors, registered users, and members see different versions based on what Dogly can help them do next. The design covers concerns capture, product explanation, plan comparison, testimonials, channels, founder story, daily plans, chat, recipes, videos, products, and a personalized library.

![The member homepage hero pairs personalized daily-plan progress with a focused return action.](/images/dogly-design-homepage-member.webp)

*For a member, the homepage becomes a return surface: current progress and the next useful action replace a generic acquisition message.*

I designed the homepage in Figma across desktop, tablet, and mobile, then built the supporting Rails architecture, responsive components, and focused Stimulus interactions.

The implementation turned repeated visual choices into shared primitives:

- Eyebrow labels and typographic hierarchy.
- Primary and secondary button treatments.
- Category-aware cards and overlays.
- Scrollable carousels with shared behavior.
- Pricing and comparison patterns.
- Tags, pills, status badges, modals, and loading states.
- Centralized breakpoint tokens.
- Configurable copy and imagery that retained the intended design structure.

![A registered-user homepage compares self-guided access with the full community membership.](/images/dogly-design-homepage-comparison.webp)

*Pricing and plan differences became part of the same visual system rather than a disconnected checkout decision.*

The design also had to account for empty libraries, missing follows, multiple dogs, incomplete onboarding, subscription state, long names, and member-specific actions. A polished default screenshot was only one state among many.

![A visitor homepage turns common concerns into concrete starting points for a personalized plan.](/images/dogly-design-homepage-start-quicker.webp)

*Visitor sections moved from broad product explanation toward recognizable problems and clear entry points.*

## Tradeoffs

### Balancing Imagery and Performance

Keeping imagery did not mean ignoring performance.

I tracked performance experiments across the homepage, Advocate profiles, Channels, daily plans, posts, products, shelters, and shop pages. The test matrix compared asset-delivery strategies, navigation changes, server configuration, and page-specific revisions using first and largest contentful paint, time to interactive, total blocking time, layout shift, bundle size, and Lighthouse score.

The results resisted a single optimization story. A change could improve paint timing on one route while increasing main-thread work or layout instability on another. The homepage work therefore also tested CDN transformations, responsive sizing, preload and preconnect behavior, font loading, and which image the browser recognized as the largest contentful paint candidate.

Some optimizations improved lab results but behaved poorly in the real page. Others reduced rendering cost without changing what users valued. The design and engineering process treated performance as one part of the experience rather than a score pursued independently of it.

## Working Through Legacy Constraints

Bootstrap was one of the most persistent constraints. Dogly inherited an old, partially customized beta-era implementation whose assumptions leaked across forms, grids, buttons, and responsive behavior.

React components, Haml templates, legacy JavaScript, and years of page-specific SCSS added other layers. A visual change could look correct on one route while an old selector quietly changed another.

I gradually moved new work toward explicit Dogly components and design tokens, removed dead selectors, centralized breakpoints, and replaced broad framework behavior where it created more uncertainty than value.

This was incremental by necessity. The shop and brand pages still retain more of the legacy language and are still candidates for the next modernization phase.

## Building Trust Through Design

Early in my tenure, part of the work was earning founder trust in design decisions.

I did that by connecting visual proposals to user behavior and product outcomes, bringing concrete designs rather than abstract criticism, and responding carefully to feedback. Over time, the review dynamic changed. By the later phases, I was usually bringing designs that needed only small refinements before approval.

That trust does not mean designing alone. It means the founders understand the reasoning, know that the work reflects Dogly's identity, and can focus feedback on the product decision rather than policing every visual detail.

## Outcome

Dogly now has a recognizable product language spanning its newest homepage, onboarding, agenda, authentication, pricing, cart, partner onboarding, and discovery work.

The system preserves the image-led quality users value while making interaction color, content hierarchy, responsive behavior, loading state, and reusable layouts more consistent.

The work also changed how new features are built. Design is no longer a finishing pass over whatever markup exists. User-facing initiatives move from a shared north star into responsive design, then into a technical plan that accounts for states, content, performance, and implementation boundaries together.

## What I'd Improve Today

I would create a small, documented component gallery backed by the actual Rails partials and Stimulus controllers. The product has a growing shared system, but its rules are still easier to discover in shipped pages than in one reference surface.

I would modernize the Advocate profile, shop, and brand pages next. They represent important customer journeys and contain the clearest remaining visual drift from the current system.

I would also formalize image art direction: target aspect ratios, focal-point metadata, overlay guidance, responsive transformations, and performance budgets by component. That would preserve the emotional role of imagery while making its delivery more predictable.


---

## SOURCE: content/case_studies/dogly-shopify-integration.md

---
title: Dogly Shopify Integration
summary: "Designing a two-way Shopify integration: bringing qualifying purchases from partner stores into Dogly, then sending Dogly marketplace orders back to brands for fulfillment."
hero_image: /images/shopify-integration-boundaries.svg
hero_alt: Diagram showing ownership and synchronization boundaries between the Dogly marketplace, integration services, and a partner Shopify store.
date: 2026-07-10
order: 3
role: Senior Software Engineer
technologies:
  - Ruby on Rails
  - PostgreSQL
  - Shopify Admin API
  - Spree Commerce
  - Active Job
  - RSpec
tags:
  - Rails
  - Integrations
  - Commerce
  - Architecture
  - Legacy Systems
  - Testing
status: published
---

## Overview

Dogly connects dog owners with independent brands, shelters, and professional advocates. Its marketplace runs on Spree inside a mature Rails application, while many partner brands operate their own Shopify stores.

The Shopify work evolved in two distinct stages. The first, shipped in late 2025, listened for qualifying purchases made on participating brands' Shopify stores, brought those customers into Dogly through signed order webhooks, and started a configurable invitation sequence. The second, developed and tested through a limited rollout in 2026, addressed the other direction: sending Dogly marketplace orders to a brand's Shopify store for fulfillment while reconciling catalog and inventory data between the two systems.

The real problem was ownership boundaries: deciding which system owned customers, products, inventory, orders, and fulfillment state, then building duplicate guards and retry boundaries around partial failure.

## Context

This work crossed Dogly's Spree-backed marketplace, brand-specific Shopify stores, background jobs, and existing ShipStation fulfillment. The two stages had different business goals, but they shared the need to make external events and identifiers understandable inside Dogly.

## Problem

Dogly needed to support brands without forcing them to abandon the systems they already used.

For the acquisition path, the purchase happened on a participating brand's Shopify site—not in Dogly. Shopify sent Dogly a signed order event; Dogly identified whether the order contained an eligible product, found or created the customer in Dogly, linked the external purchase, and scheduled brand-specific invitations to Dogly's expert content and membership product.

For marketplace fulfillment, a Dogly order could contain products from multiple brands. Each brand needed only its own line items in its own Shopify store. Product and inventory data also needed a durable mapping across two catalogs that used different identifiers and did not always share clean SKUs.

The existing ShipStation flow also stayed available for legacy brands, which let teams transition to Shopify incrementally instead of forcing a hard cutover.

## Constraints

- Preserve an existing Spree checkout and order lifecycle.
- Configure credentials, product filters, and invitation timing per brand.
- Acknowledge webhooks quickly and perform slower work asynchronously.
- Treat webhook delivery as at-least-once and make repeated processing safe at each side effect.
- Split multi-brand orders without leaking another brand's line items.
- Avoid making either catalog an accidental second source of truth.
- Support operator review when automatic SKU or name matching was uncertain.
- Roll the fulfillment path out incrementally and be willing to pull it back when checkout assumptions proved unsafe.

## My Role

As Dogly's sole engineer, I owned the work from technical planning through implementation and production support for the acquisition path, plus the design, implementation, and limited rollout of the fulfillment path. That included the webhook boundary, background jobs, customer association, invitation sequencing, per-brand configuration, order transmission, catalog import and reconciliation, inventory mapping, admin workflows, and focused tests around failure-prone paths.

I also worked directly with the founders to separate the immediate business need from the larger integration platform. That distinction kept the first customer-acquisition workflow small enough to launch while giving the later commerce work clearer boundaries.

## Approach

I treated each external system as a bounded collaborator with explicit ownership, asynchronous work, durable mappings, and idempotent side effects. The first stage optimized for a fast, safe customer-acquisition path; the second added fulfillment and reconciliation behind a limited rollout.

## Technical Implementation

## Stage One: Partner-Store Purchases into Dogly

The first integration accepts signed Shopify order webhooks from a configured brand store. The order originated on the partner's site; Dogly's endpoint only verified the HMAC signature, identified the brand, enqueued the raw payload, and returned promptly.

The background processor then checked whether the order contained an eligible product. If so, it found or created the customer in Dogly, recorded the Shopify relationship, associated the order, and scheduled the configured invitation sequence.

Several duplicate guards were necessary because there was no single universal definition of "already processed":

- Customer email lookup, backed by the existing account constraint, prevented duplicate Dogly accounts; the processor also recovered from a concurrent-create race.
- Shopify customer and order notes preserved the external relationship.
- Order-plus-day markers let invitation jobs skip work already recorded as sent.
- Jobs rechecked state when they ran instead of trusting the state that existed when they were scheduled.

That last point mattered for delayed jobs. A customer might accept an invitation, unsubscribe, or receive another order between scheduling and execution.

## Stage Two: Marketplace Fulfillment

The fulfillment direction introduced a different ownership model. Dogly remained the customer-facing marketplace and source of the complete order. Each Shopify store received a brand-specific fulfillment order containing only its products.

The staged transmission flow grouped line items by brand, selected only brands configured for Shopify fulfillment, built the Shopify payload for each brand, and recorded the returned external order ID against the Dogly order.

![Order transmission sequence](/images/shopify-order-sequence.svg)

Recording external IDs per brand made retries safer. Before transmitting, the service checked whether that brand's portion had already succeeded instead of resending the entire marketplace order. This was a pragmatic guard, not a fully atomic idempotency guarantee; a timeout after Shopify accepted an order but before Dogly persisted the ID remained a failure mode to solve before broader release.

Fulfillment webhooks traveled in the reverse direction. After signature verification, they located the corresponding Dogly shipment and recorded tracking and shipment state without re-running unrelated checkout behavior.

## Catalog Reconciliation

Catalog synchronization could not depend on perfect SKUs. Some products matched cleanly by SKU, some only by normalized name, and some required a person to decide.

The admin reconciliation workflow therefore separated three states:

- Already linked.
- Suggested match.
- Unmatched Shopify product.

An operator could confirm a proposed match, import a new product, ignore an irrelevant item, or revisit a partial import. Imported variants retained Shopify variant and inventory-item identifiers so later inventory events did not have to repeat fuzzy matching.

Images were imported through background jobs after the product transaction committed. That kept remote downloads outside the database transaction and made image failure recoverable without rolling back an otherwise valid catalog record.

## Tradeoffs

### Operational Lessons

The fulfillment and catalog work went through integration, rollback, and selective restoration as it met the realities of the mature checkout code and overlapping feature branches. I did not treat a completed implementation as proof that the operational model was ready. The rollout exposed assumptions about payment timing, stock locations, variant ownership, and merge boundaries that were safer to discover at limited scope than after broad adoption.

The implementation added explicit logging, surfaced transaction rollback errors, and provided admin-visible states for missing credentials, taxonomy, option types, and SKU conflicts. The goal was to make incomplete work diagnosable rather than silently wrong. Catalog and configuration tooling could be restored independently while automated order transmission remained held back.

## Outcome

More than 1,000 retained Dogly user records carry a Shopify-customer association from the production acquisition path. That path began with a limited rollout to a single product from a single brand in the first month. The total is a count of records connected to the channel, not a claim that every recipient activated or became a paid member. The integration turned partner purchases into configurable onboarding while guarding against duplicate accounts and repeated invitation sequences.

The later commerce work established and exercised the boundaries for per-brand order transmission, fulfillment callbacks, catalog reconciliation, product import, and inventory mapping. The limited rollout produced synchronized catalog and order records, but automated fulfillment was not broadly released; the safer outcome was retaining useful administrative tooling while revisiting the checkout boundary.

The most durable outcome was a clearer model of ownership: Dogly owns the marketplace order and customer experience; partner stores own fulfillment and their source catalog; explicit external identifiers connect the two. Just as importantly, the rollout established where that model still needed stronger guarantees before expansion.

## What I'd Improve Today

I would formalize every cross-system operation around a persisted integration event with a unique idempotency key, payload digest, state, attempt count, and last error. The existing notes and external-ID mappings cover important duplicate cases, but a common event model with database-enforced uniqueness would close the timeout gap and make replay and support work easier.

I would also make the staged rollout explicit through per-brand feature states rather than relying on configuration presence alone. A state such as disabled, shadowing, catalog-only, and fulfillment-live would better communicate operational intent.

I would also set up partner-specific packing inserts that highlight Dogly and guide customers toward follow-up engagement after fulfillment. That would give each brand a lightweight, consistent way to extend the experience beyond the shipment itself.

Finally, I would add contract tests around recorded Shopify payloads and a full integration test covering a multi-brand order in which one transmission succeeds and another fails. That is the scenario where clear retry boundaries matter most.


---

## SOURCE: content/case_studies/federation-briefing.md

---
title: The Federation Briefing
summary: Turning a week of Star Trek community discussions into a sourced AI briefing that shows its work and knows when it does not have enough evidence.
hero_image: /images/federation-briefing-pipeline.svg
hero_alt: Pipeline diagram showing reviewed community data becoming an evidence-linked Federation Briefing.
date: 2026-07-20
order: 7
role: Software Engineer
technologies:
  - Python
  - OpenAI API
  - Streamlit
  - scikit-learn
  - Reddit
  - Pytest
tags:
  - AI Engineering
  - RAG
  - Python
  - Evaluation
  - Data Ingestion
  - Testing
status: published
---

## Overview

[The Federation Briefing](https://github.com/JaredHarbison/the-federation-briefing) is a small AI application that turns a week of public Star Trek community discussions into a sourced briefing.

I was interested in more than whether an AI model could summarize a group of posts. I wanted the application to show which discussions it used, connect its claims to those sources, and be honest when it did not have enough evidence to answer a question.

The result is a Streamlit application with live Reddit ingestion, local and OpenAI-powered search, source labels, an offline mode, and a side-by-side comparison that shows how much current source material changes the report.

## Problem

An AI-generated report can sound informed even when the source material is weak or unrelated. Many demos hide that problem by showing the answer without showing how it was produced.

For this project, I wanted the evidence to stay visible. The application needed to separate what people actually discussed from what it predicted might happen next, link claims back to specific posts, and decline questions that the week's discussions could not support.

## Context

This is a focused prototype, not a production analytics service. It works with up to 25 public `r/startrek` discussions from a seven-day period. Streamlit provides the interface, while a small set of Python modules and scripts handle data collection, search, report generation, and the reviewed offline snapshot.

The project supports two operating modes:

- A local path uses TF-IDF search and fallback reports.
- An OpenAI path uses embeddings and AI-generated reports.

For the default question, the repository includes a reviewed pair of OpenAI reports: one with current sources and one without them. This keeps the full comparison available when live generation is unavailable.

## Constraints

- Never send an API key to the browser or commit it to the repository.
- Preserve a usable, reproducible offline mode when API access is unavailable.
- Use only retrieved discussions as evidence for current community claims.
- Keep the comparison report separate from posts, dates, source titles, and search results.
- Decline a custom question when the week's posts do not support it.
- Fall back to Reddit's public RSS feed when its JSON endpoint is blocked.
- Never let a failed or malformed fetch silently replace the reviewed data.
- Keep each part of the workflow small enough to inspect and test.

## My Role

I designed and built the complete prototype: Reddit ingestion, the reviewed snapshot workflow, local search, OpenAI integration, source selection, prompts, unsupported-question handling, offline fallbacks, the comparison interface, and tests.

I also designed the comparison. Both reports answer the same question using the same five sections. One receives no current community posts, while the other receives only the posts selected by the search process. The main difference between them is access to current evidence.

## Approach

I divided the workflow into four steps: collect and review the source data, make it searchable, select useful evidence, and generate the report.

![The Federation Briefing pipeline from reviewed community data through retrieval and evidence-linked reporting](/images/federation-briefing-pipeline.svg)

New Reddit data is first written to a temporary local file instead of replacing the saved snapshot. A separate command checks the required fields, dates, and discussion URLs before the new data can be promoted. This prevents a bad response from quietly becoming the application's trusted example data.

One broad search was not enough for a useful weekly briefing. It tended to return several versions of whichever topic dominated the small set of posts. I split the search into five areas:

- The analyst's stated focus.
- Releases and upcoming events.
- Debates and criticism.
- Newcomer questions.
- Creative participation.

The application ranks posts within each area, gives a small boost to posts with more engagement, and takes turns selecting from each list while removing duplicates. The final report uses no more than eight posts.

## Technical Implementation

The local version uses scikit-learn's TF-IDF search. I give post titles extra weight so a clear title does not get buried by a much longer body. When an API key is present, the same posts and search areas use OpenAI embeddings instead.

Each selected post includes its similarity score and the reason it was chosen. The interface shows those details in source cards beside the report. It also explains that similarity measures how closely a post matched a search—not whether the post or report is correct.

The sourced report receives only the selected posts, labeled `S1` through `S8`. Its instructions require citations for claims about the community, prevent the model from inventing an opposing view just to create a debate, and clearly label predictions as predictions.

The comparison report uses the same headings but receives no community posts, dates, sources, or search results. It must use conditional language rather than present general Star Trek knowledge as something the community discussed that week.

Before answering a custom question, the application checks whether its important terms appear in the week's posts and whether the closest matches are strong enough. If not, it returns an insufficient-evidence message instead of asking the model to make something out of unrelated discussions.

Without an API key, the application still runs the real local search. For the default question, it can also show the saved OpenAI comparison. A separate generation script checks the report structure, required citations, and separation between the two reports before saving that result.

Tests cover the data structure, search relevance and variety, supported and unsupported questions, separation between the two reports, source labels, matching report sections, and the seven-day ingestion window.

## Tradeoffs

The dataset is deliberately small and represents one subreddit over one week. It cannot support claims about the broader Star Trek audience. Reddit scores provide a small ranking signal, but popularity does not make a post representative.

The check for unsupported questions uses simple word matching and hand-selected similarity limits. It is understandable and testable, but those limits were not measured against a large set of reviewed questions.

The local search is intentionally simple, and the vectors and search counts live in JSON files. That makes the prototype portable, but it would not work well for many simultaneous users or a much larger collection.

The five search areas reflect my idea of what makes a useful weekly briefing. They improve variety, but they can also give space to a category with weak results. A production version should be willing to skip an area when its evidence is not good enough.

Finally, data collection and review are run through commands. There is no production scheduler, hosted application, moderation process, or background job system.

## Outcome

The finished prototype shows how the report was made. The interface includes the selected sources, why each one was chosen, the report without current context, the sourced report, search frequency, and a map of related posts.

It also handles three common failure cases: no API key, unavailable OpenAI generation, and a question the data cannot support. In each case, the application explains what changed instead of quietly presenting an unsupported answer.

The side-by-side comparison is the most useful result. The question and report structure stay the same while the source material changes. That makes it much easier to see what retrieval actually adds: current context, visible sources, support for claims, and a more honest basis for predictions.

## What I'd Improve Today

I would create a reviewed set of questions the system should and should not answer, then measure whether it found the right sources, cited them correctly, and declined the right questions. The current tests cover important examples, but they do not measure performance across a broad set of questions.

I would replace the local JSON files with a small database and keep each data import, source post, search, generated report, and model setting. That would support multiple users and make reports easier to reproduce and compare across weeks.

I would schedule data collection, handle rate limits, clean and deduplicate posts, and add a review step before publication. I would also include more than one community source so the briefing did not treat a single subreddit as the entire fandom.

Finally, I would check every generated claim against its cited posts instead of relying mainly on prompt instructions. Unsupported sentences should be flagged for review before a briefing can be published.


---

## SOURCE: content/case_studies/fridge-no-more-bulk-ordering.md

---
title: Fridge No More Bulk Ordering
summary: Turning Dogly's retail catalog into an operational bulk-ordering workflow that produced a first retained order of $11,935.90 across 210 cases.
hero_image: /images/quickshipper-order-flow.svg
hero_alt: QuickShipper bulk-ordering workflow from catalog selection through fulfillment.
date: 2026-07-11
order: 6
role: Software Engineer
technologies:
  - Ruby on Rails
  - Spree Commerce
  - PostgreSQL
  - JavaScript
  - Haml
tags:
  - Rails
  - Product Engineering
  - Commerce
  - Integrations
  - Operations
  - Legacy Systems
status: published
---

## Overview

In 2021, Dogly partnered with Fridge No More, a rapid grocery-delivery company, to create a new wholesale channel for independent pet brands already selling through Dogly.

The opportunity arrived with a short timeline. Fridge No More needed to order cases of products from multiple Dogly brands for its fulfillment locations. Dogly's existing Spree storefront was built for consumer purchases, individual units, and normal checkout, not for an operator assembling a bulk replenishment order across brands and warehouses.

I shipped the initial usable workflow in roughly two weeks, then continued hardening the operational details through the following weeks. The first retained production order totaled $11,935.90 across 210 cases.

## Context

The work extended a mature Rails marketplace using Spree for consumer commerce. The new workflow had a different buyer, order shape, fulfillment destination, and operational lifecycle, but it still needed to reuse Dogly's product catalog and existing account boundaries.

## Problem

The product catalog already contained the items Fridge No More wanted, but the normal storefront represented the wrong purchasing model.

A bulk buyer needed to:

- See only products approved for the partnership.
- Order in cases rather than individual consumer units.
- Send inventory to a specific fulfillment warehouse.
- Combine products from multiple brands in one working order.
- Understand category-specific shipping thresholds.
- Preserve tracking, invoice, payment, and operational notes after submission.

Building a completely separate wholesale catalog would have duplicated products and created another source of truth. Forcing the process through ordinary Spree checkout would have buried the operational information the Dogly team and brands needed.

## Constraints

- Ship a usable first workflow on a short partnership timeline.
- Reuse Spree products without duplicating the catalog.
- Keep bulk ordering separate from consumer checkout and payment assumptions.
- Preserve partner access controls, warehouse destination, shipping rules, tracking, and invoice state.

## My Role

I designed and implemented the workflow across the Rails stack. I worked with Dogly's founders to turn the partnership requirements into a deliberately narrow first release, then built the data model, admin and partner interfaces, product selection behavior, shipping calculations, order history, tracking updates, notes, and access controls.

The schedule required fast decisions about what could reuse Spree and what needed a separate operational model.

## Technical Implementation

The implementation used a dedicated `QuickOrder` boundary with line items that referenced Spree products while storing bulk-specific quantities, categories, shipping, and totals. Separate partner and admin views exposed the operational lifecycle after submission.

## Approach

I kept Spree as the source of product truth while introducing a parallel order type for the wholesale workflow.

Each QuickShipper had access to configured warehouses and a curated set of Spree products. Special partnership items were organized through a dedicated taxon, allowing Dogly to reuse product data while controlling exactly what appeared in the bulk-order interface.

The submitted record was a `QuickOrder`, not a normal consumer order. Its line items referenced the underlying Spree products but stored bulk-specific values such as case quantity, item quantity, category, shipping cost, and total cost.

This boundary avoided pretending a bulk replenishment order had the same lifecycle as a consumer checkout.

## Ordering Experience

The ordering screen grouped eligible products by category and let an authorized operator enter case quantities. It displayed the selected warehouse, recalculated totals as quantities changed, and created the order and line items through separate endpoints.

After submission, both Dogly administrators and authorized QuickShipper users could review past orders. The order page became the shared operational record for:

- Products and quantities.
- Warehouse destination.
- Carrier and tracking numbers.
- Internal and partner-visible notes.
- QuickBooks invoice link, due date, and payment state.
- Canceled, due, past-due, and paid status.

## Shipping Rules

Shipping was not a single order-level value. Different product categories could have their own free-shipping threshold and normal shipping cost.

The order grouped line items by category, summed the category's merchandise cost, and compared it with the relevant shipping minimum. If the order did not meet the threshold, the category's shipping charge was distributed across its line items. If it did, those line items received no shipping charge.

That calculation ran after the order and line items committed, when the complete category composition was available.

## Tradeoffs

The fastest path reused the existing product taxonomy and shipping logic. That reduced duplicate configuration, but it also tied the QuickShipper workflow to conventions that had originally been designed for retail checkout.

The JavaScript submission flow created the order and then its line items through multiple requests. That made the UI straightforward to ship, but a single transactional submission endpoint would have provided a stronger all-or-nothing boundary.

The integration was also intentionally partner-specific. I kept the domain model partner-neutral rather than naming it after Fridge No More, but I did not build a generalized wholesale platform before Dogly had evidence that more partners needed one.

## Outcome

The first retained production order totaled $11,935.90 and represented 210 cases of products from Dogly's brands. It validated a new revenue channel without duplicating Dogly's catalog or forcing a wholesale workflow into consumer checkout.

The partnership continued for several months before Fridge No More ceased operations. That limited the lifetime of the channel, but not the value of the engineering result: Dogly went from a partnership request to a working, revenue-producing operational system on a short schedule.

## What I'd Improve Today

I would submit the order and all line items through one command object and database transaction, then calculate category shipping from the committed order through an explicit pricing service.

I would also represent price, pack size, and shipping rules as versioned partnership terms instead of reading some behavior indirectly from retail products and shipping categories. That would make historical orders easier to explain if catalog configuration changed.

Finally, I would add a lightweight integration status model for invoice and fulfillment events. The existing fields and notes worked for one partner, but a second partner would justify a more explicit event history.


---

## SOURCE: content/case_studies/karaoke-queue.md

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


---

## SOURCE: content/pages/about.md

---
title: About
summary: "I am a Senior Software Engineer who builds practical product software: the kind that has to be understandable by users, maintainable by future engineers, and honest about the constraints it lives inside."
status: published
---

My recent work has centered on Ruby on Rails applications with mature domains: marketplaces, onboarding flows, partner tools, admin workflows, content systems, and user-facing discovery experiences. I also work comfortably across React, Stimulus, SCSS, PostgreSQL, and the connective tissue between product decisions and implementation details.

At Dogly, I have worked as both a sole engineer and a technical partner to founders. That has meant moving between product planning, architecture, implementation, and delivery; making tradeoffs with incomplete information; and taking responsibility for what happens after a feature reaches production.

I tend to care most about the shape of the system. Controllers should stay thin. Domain behavior should have a clear home. Views should be readable. JavaScript should earn its place. Tests should cover the risk that actually matters.

Before software, I spent years leading high-volume retail teams and building operational programs. That experience still shapes how I work: I pay attention to the people using a system, communicate directly with stakeholders, and treat operational constraints as product inputs rather than afterthoughts.

Right now I am looking for opportunities where I can keep growing alongside strong engineers while contributing as someone who can build products end-to-end.


---

## SOURCE: content/writing/frontline-process-design.md

---
title: Frontline Process Design
summary: A retail communication problem taught me to design around where work happens, not where a process document assumes it happens.
date: 2026-07-11
order: 2
category: Leadership
tags:
  - Product Engineering
  - Leadership
  - Operations
status: published
---

Before I became a software engineer, I led a retail location doing roughly $12 million in annual business.

Managers carried an extraordinary amount of context through a normal day: associate performance, customer issues, product changes, visual standards, operational exceptions, and decisions the next leader needed to understand.

The store had a process for communicating that context. It did not have a process people could consistently use.

## The Back-Office Document

Like many stores at the time, we kept a shared Word document on a computer in the back office. Managers were expected to leave notes in it during the day. At closing, the document was emailed to the management team.

The document technically centralized information. Operationally, it had several problems:

- Updating it required leaving the sales floor.
- It was available from one physical location.
- People, product, and process notes accumulated in one stream.
- Finding an older decision was difficult.
- The final email arrived after much of the information would have been useful.

When managers complained about the process—or simply stopped following it—I did not begin by reminding them that compliance was expected. I treated noncompliance as product feedback.

## Start With the Bottleneck

The problem was not that managers were unwilling to communicate. They were busy, mobile, and rarely near the one computer where the process lived.

The store already had an interface available from iPads, iPhones, registers, satellite computers, and the back office: email.

I replaced the single document with three persistent team threads:

- **People** for associate and staffing information.
- **Product** for merchandise, inventory, and presentation.
- **Process** for operational decisions and changes.

A manager who needed to record an associate note could reply all to the People thread from the closest device. The subject and conversation history supplied enough structure to keep related information together. Search worked across every device without introducing another application or login.

## Why the Small Solution Worked

The change did not ask managers to become less busy. It moved the process into the places where their work already happened.

It also improved information architecture. Dividing communication into People, Product, and Process made messages easier to scan and historical decisions easier to retrieve.

Most importantly, the solution used familiar behavior. No training program was required beyond explaining which thread held which kind of information.

After a month, I checked back with the management team instead of assuming adoption meant success. Everyone preferred the new process. Other stores began using it as well.

## What This Changed About How I Build Software

I still approach broken workflows the same way.

If people avoid a process, I want to know where it asks them to leave their actual work. If information is repeatedly missing, I look for the point where capture becomes inconvenient. If a proposed system requires significant training, I ask whether an interface people already understand can carry more of the load.

This does not mean every problem can be solved with email. It means the smallest successful system may be an arrangement of existing tools rather than a new tool.

The lesson I carried into engineering is simple: a process is not well designed because its instructions are clear. It is well designed when people can follow it under the conditions in which they really work.


---

## SOURCE: content/writing/idempotent-webhooks-in-rails.md

---
title: Idempotent Webhooks in Rails
summary: Practical patterns for making at-least-once delivery safe across controllers, jobs, records, and delayed side effects.
date: 2026-07-10
order: 5
category: Integrations
tags:
  - Rails
  - Integrations
  - Architecture
  - Testing
status: published
---

A webhook provider is allowed to send the same event more than once. Your application is not allowed to charge, invite, fulfill, or email someone more than once because of it.

That difference is where webhook design begins.

## Keep the Controller Boundary Small

A webhook controller should authenticate the request, capture the information required for processing, enqueue work, and respond quickly.

It should not perform a long synchronization while the provider waits. A timeout can cause the provider to retry an operation that actually succeeded, creating concurrency precisely when the application is least prepared for it.

Signature verification belongs before the enqueue. Store secrets per integration account when multiple customers or partners can connect the same provider.

```ruby
def create
  integration = Integration.find_by!(external_key: params[:account])
  head :unauthorized unless valid_signature?(integration)

  ProcessWebhookJob.perform_later(integration.id, request.raw_post)
  head :ok
end
```

The real implementation also needs payload limits, safe parsing, and useful error reporting. The important boundary is that authentication is synchronous while business processing is not.

## Choose an Idempotency Key for the Side Effect

"Have I seen this payload?" and "Have I performed this action?" are different questions.

One external order can legitimately cause several actions:

- Associate the order with a customer.
- Send an initial invitation.
- Send a follow-up two days later.
- Update an acquisition report.

A single processed flag is too coarse. Each side effect needs a key at the level where duplication would be harmful.

For example:

```text
shopify-order:8472:associate-customer
shopify-order:8472:invite:day-0
shopify-order:8472:invite:day-2
```

That model permits new behavior to be added without reopening old effects.

## Enforce Uniqueness in the Database

An application-level existence check is useful for readability, but it does not prevent two workers from passing the check simultaneously.

The database should enforce the invariant:

```ruby
add_index :integration_events,
  %i[integration_id idempotency_key],
  unique: true
```

The worker can then insert the event and treat a uniqueness violation as evidence that another worker already claimed it. This is more reliable than a distributed lock for many webhook workloads because the record also becomes an audit trail.

## Recheck State When Delayed Work Runs

A delayed email job should not assume the user is still in the state that caused the job to be scheduled.

Between scheduling and execution, the person may have:

- Accepted the invitation.
- Unsubscribed.
- Purchased again.
- Been merged into an existing account.
- Received the same communication through another workflow.

The job should load current state, claim its specific idempotency key, and then decide whether the effect is still appropriate.

## Make Partial Success Visible

Consider a marketplace order split between three external stores. Two transmissions succeed and one fails.

Retrying the entire order is unsafe. Discarding the entire attempt is inaccurate. The useful unit of state is the brand-specific transmission:

```text
Dogly order
├── Brand A → transmitted: external order 101
├── Brand B → failed: invalid variant mapping
└── Brand C → transmitted: external order 303
```

Persist external IDs and failure state at that boundary. A retry can then target Brand B without duplicating A or C.

## Test Repetition, Not Only Success

The happy-path test proves that the integration works once. The risk-oriented tests prove that it remains safe:

- Deliver the same payload twice.
- Run the same job concurrently.
- Fail after the external API succeeds but before the local record updates.
- Schedule a delayed effect, change the user's state, then run it.
- Process a multi-tenant payload with one invalid tenant configuration.

Webhook reliability is less about preventing every failure than ensuring that failure has a stable place to land.

## The Larger Principle

Idempotency is not a controller concern or a job concern. It is a property of a business effect across the whole path.

Authenticate early. Acknowledge quickly. Persist a key at the same granularity as the side effect. Let the database arbitrate concurrency. Recheck delayed decisions. Record partial success.

Once those boundaries are explicit, retries stop being frightening. They become a normal operating mode.


---

## SOURCE: content/writing/product-catalog-reconciliation.md

---
title: Product Catalog Reconciliation
summary: How to combine exact identifiers, cautious matching, operator decisions, and durable mappings when two commerce systems disagree.
date: 2026-07-09
order: 6
category: Integrations
tags:
  - Rails
  - Integrations
  - Commerce
  - Architecture
  - Product Engineering
status: published
---

Synchronizing two product catalogs sounds like copying fields until you meet the first real catalog.

One system has products with variants. The other has separate products for each size. SKUs are missing, duplicated, or formatted differently. Categories use different names. One side considers inventory global while the other separates it by location.

The engineering problem is not import. It is identity and ownership.

## Start by Declaring Ownership

Before matching a record, decide which system controls each field.

For a marketplace connected to a brand's commerce platform, a reasonable split might be:

| Concern | Owner |
| --- | --- |
| Brand product identity | Brand platform |
| Marketplace copy and taxonomy | Marketplace |
| Fulfillable inventory | Brand platform |
| Marketplace price promotion | Marketplace |
| Order and customer experience | Marketplace |
| Shipment execution | Brand platform |

Without that decision, "sync" quietly becomes last-write-wins. A copy edit in the marketplace can be erased by inventory polling because both operations update the same undifferentiated record.

## Match in Layers

Use the strongest available identity first:

1. Persisted external product or variant ID.
2. Exact, unique SKU.
3. Normalized SKU.
4. Exact normalized product name.
5. Human review.

Do not allow a weak match to masquerade as a strong one. A name match should produce a suggestion, not silently create a durable mapping.

Each proposed match should explain itself:

```text
Suggested match
Shopify: Trail Harness / Blue / Medium
Dogly:   Trail Harness - Blue (M)
Reason:  normalized SKU TH-BLU-M
```

That explanation is useful both to the operator and to the engineer debugging a bad association later.

## Preserve the Decision

Once an operator confirms a match, persist the external IDs. Do not repeat fuzzy matching during every inventory webhook.

The mapping should reach the lowest level required by later events. If inventory updates identify a variant and inventory item, store both. A product-level mapping alone forces the application to rediscover variant identity at the worst possible moment: during a time-sensitive stock update.

## Make Unmatched a Valid State

An integration UI often treats unmatched records as errors. They are usually work.

An external product might be:

- Not intended for the marketplace.
- Missing required taxonomy.
- A duplicate or archived item.
- Waiting for photography or copy.
- Valid, but not safely matchable.

Useful operator actions include:

- Import.
- Link.
- Ignore.
- Retry.
- Reopen a partial import.

"Ignore" should be persisted. Otherwise every refresh asks the operator to reconsider the same intentional exclusion.

## Keep Remote Work Outside Transactions

Downloading product images inside the product transaction extends locks and couples remote reliability to local consistency.

A safer flow is:

1. Create or update the product and mappings in a transaction.
2. Commit.
3. Enqueue image imports.
4. Record image failures separately.

The product can exist without all images. It should not disappear because a CDN timed out.

The same principle applies to inventory. Update the stock location owned by the integration instead of every stock location attached to the variant.

## Design the Reconciliation Screen as an Operations Tool

An admin page is not a thin wrapper around an API response. It is where uncertainty becomes a decision.

Show:

- Connection and credential status.
- Counts for linked, suggested, unmatched, ignored, and failed records.
- The fields used to make a suggestion.
- Missing SKU, option, taxonomy, and inventory-location warnings.
- The last successful sync and most recent error.
- A safe way to retry one record.

The interface should answer two questions quickly: "What needs attention?" and "What will this action change?"

## Test the Messy Catalog

Useful fixtures include:

- Duplicate SKUs.
- A product with no variants beyond the default variant.
- Multiple option dimensions.
- An image that fails after the product saves.
- An existing mapping whose external product was archived.
- Zero and fractional inventory values.
- Two products whose names normalize to the same string.

A clean three-product fixture proves the parser works. A messy fixture proves the reconciliation model works.

## The Larger Principle

Catalog integrations become reliable when they stop pretending uncertainty can be automated away.

Declare ownership. Prefer durable identifiers. Rank weaker matches. Put a person in the loop where ambiguity is real. Preserve their decision. Separate remote side effects from local transactions.

The goal is not a magical sync button. It is a system in which both automation and uncertainty are visible.


---

## SOURCE: content/writing/product-imagery-and-performance.md

---
title: Product Imagery and Performance
summary: Performance matters, but removing the visual quality users value is not automatically an optimization.
date: 2026-07-11
order: 4
category: Product Engineering
tags:
  - Product Engineering
  - Architecture
  - Operations
status: published
---

Images are easy to treat as excess.

They are large. They complicate responsive layouts. They affect largest contentful paint. They need crops, alt text, contrast protection, and a delivery pipeline. A minimal interface is easier to benchmark and often easier to maintain.

But performance is not the only thing a user experiences.

## Listen Before Simplifying

In user feedback at Dogly, people consistently told us they loved the imagery.

That changed the optimization question. Removing images might improve a lab score, but it would also remove something users explicitly associated with the product's value. A modest improvement they did not perceive could come at the cost of an emotional loss they noticed immediately.

The requirement became: keep the imagery, then make its cost intentional.

## Give Images a Job

An image should do more than fill a rectangle.

At Dogly, the three principal guidance categories developed distinct environments:

- Training used grass and dogs in active outdoor settings.
- Nutrition used concrete and grounded surfaces.
- Wellness used sky and open atmosphere.

The system was flexible, but it made image selection coherent. A person moving through the product received subtle category cues before reading every label.

Photography also carried warmth and credibility that abstract interface decoration could not. Dogly is about helping people improve life with their dogs. Showing those dogs and relationships was part of the product promise.

## Design Text and Images Together

Text over photography fails when the image is selected first and readability is addressed later.

Useful image-led components define:

- Expected aspect ratio.
- Safe focal area.
- Text placement.
- Overlay strength.
- Light and dark text variants.
- Minimum contrast.
- Behavior when the crop changes.
- A fallback when the image is absent.

Layers are not merely aesthetic. They allow one image to remain useful across content variation and viewport sizes while protecting the interface hierarchy.

## Optimize Delivery, Not Meaning

Once the image has a product role, performance work can focus on delivery:

- Serve an appropriately sized source.
- Transform through an image CDN.
- Prefer modern formats.
- Reserve dimensions to prevent layout shift.
- Load below-the-fold media lazily.
- Prioritize the actual hero candidate.
- Avoid loading separate desktop and mobile assets when art direction does not require both.
- Test real breakpoints rather than only a wide desktop and narrow phone.

The best implementation is not always the one with the smallest image count. It is the one that delivers the intended visual experience without making the browser download work the user cannot see.

## Treat Lab Scores as Evidence

Performance tools are valuable because perception is unreliable. They reveal blocking resources, oversized assets, layout movement, and rendering paths that are difficult to diagnose by feel.

They are still evidence, not the entire product decision.

An optimization that improves a score but causes the browser to stop recognizing the correct largest-contentful-paint element may be misleading. A technique that looks good on a first load may behave differently through client-side navigation. A hero that renders quickly but no longer communicates the product can be technically faster and experientially worse.

## The Larger Principle

Optimization means improving the product under its real constraints.

Sometimes that means removing an image that has no job. Sometimes it means spending engineering effort to preserve an image because users have told you it matters.

Minimalism is a visual choice, not proof of product discipline. The disciplined choice is knowing what users value, giving it a clear role, and delivering it responsibly.


---

## SOURCE: content/writing/product-planning-and-scope.md

---
title: Product Planning and Scope
summary: How I move a team from unconstrained ideas to a shared north star, prioritized MVP, design, and reviewable technical scope.
date: 2026-07-11
order: 1
category: Collaboration
tags:
  - Product Engineering
  - Leadership
  - Architecture
  - Operations
status: published
---

I like to begin a project with fewer constraints than I intend to end with.

Starting with feasibility too early causes teams to edit themselves before they understand what they actually want. Starting without any path back to scope produces an inspiring meeting and an impossible project.

My job in early planning is to make room for both modes: expansive ideation first, then increasingly concrete decisions.

## Put Everything on the Table

I lead the founders and team through a rough ideation meeting where the rule is to capture everything we would like to see regardless of current limitations.

This is not the moment to debate implementation, estimate tickets, or defend the existing system. Product needs, customer frustrations, operational concerns, visual ideas, ambitious extensions, and small conveniences all belong in the same raw collection.

The point is not that every idea is equally good. The point is that people should not have to win a prioritization argument merely to make an idea visible.

## Use AI for Organization, Not Authority

After the meeting, I use AI to organize and categorize the raw notes and propose a one-line description of the project's north star.

That is clerical and synthesizing work, not decision-making authority. The model can group overlapping ideas, identify themes, and suggest language. It does not decide what the business values or what the team commits to.

I take the organized material back to the team quickly. We revise and agree on the north star together before treating any category or summary as settled.

A useful north star is specific enough to reject work. If every idea supports it equally, it is a slogan rather than a decision tool.

## Prioritize in Two Dimensions

Once the team agrees on the outcome, we rank ideas along two related dimensions:

- **Need to have / love to have:** How important is this to the experience?
- **MVP / iteration:** Does it have to exist for the first useful release, or can it follow after learning?

Those are not interchangeable.

A feature can be something we would love to have eventually but still belong in the MVP because it is cheap and removes substantial risk. A need-to-have capability may be delivered through a deliberately narrow first version with deeper behavior deferred.

The distinction helps the team discuss value and sequence instead of collapsing every decision into priority numbers.

## Design Before Technical Commitment

For user-facing work, I take the prioritized MVP into design before finalizing the technical plan.

Design exposes missing states and hidden product decisions: empty results, permissions, partial progress, validation, errors, mobile behavior, and what the user believes has happened after an action.

Writing a detailed technical plan before those questions are visible often creates false confidence. The estimate appears precise because the interaction is still vague.

## Make the Technical Plan Reviewable

Once the designs are ready, I build the technical plan for review.

The plan explains:

- The existing behavior and boundaries being changed.
- The proposed architecture.
- Data and lifecycle changes.
- External dependencies.
- Failure and recovery paths.
- Testing strategy.
- Rollout sequence.
- Expected scope, time, and resources.

The purpose is not to ask non-engineers to approve class names. It is to let everyone understand what the approved product requires and where the meaningful tradeoffs remain.

Final approval should feel like the conclusion of a sequence of shared decisions, not the first time someone discovers the cost of an idea.

## Why This Works From Below

Earlier in my career, I used a similar pattern as a retail director managing specialists: prepare with individual owners, align the group, resolve feedback, and return quickly with a hardened plan.

As an engineer working closely with founders, leadership is less about reporting structure and more about creating the sequence in which good decisions can happen.

I cannot decide the business priority alone. A founder cannot responsibly estimate technical risk alone. A designer should not be asked to resolve an undefined objective through interface polish.

The process gives each person a clear place to contribute while keeping the team moving toward commitment.

## The Larger Principle

Good planning alternates between divergence and convergence.

Open the space enough to discover the real opportunity. Organize without pretending organization is agreement. Agree on the outcome. Separate value from sequence. Design the experience. Then make scope and technical risk explicit.

The deliverable is not merely a technical plan. It is a plan the team understands well enough to approve together.


---

## SOURCE: content/writing/rails-static-content.md

---
title: Rails for Static Content
summary: Why I chose a small Rails app with Markdown content for this site instead of a static site generator.
date: 2026-07-08
order: 7
category: Architecture
tags:
  - Rails
  - Architecture
  - Content
status: published
---

This site is intentionally boring at the infrastructure level.

It is a Rails app with no database, no authentication, no admin panel, and no frontend framework. Content lives in Markdown files. Rails renders those files through normal controllers and views.

That might seem like using too much framework for a personal site, but I think it is a useful shape.

Rails gives me routing, layouts, helpers, caching, asset handling, testing, and a future path to ActiveRecord without forcing those decisions on day one. Markdown gives me the authoring experience I want right now. The repository layer sits between those two choices so the app does not care whether content comes from files today or database rows later.

The important constraint is keeping the app static in spirit. A personal site does not need a client-side router, a CMS, or a large JavaScript bundle to render essays and case studies. It needs readable templates, good typography, semantic HTML, and a content model that does not fight the author.

The architecture is small on purpose:

- A `ContentRepository` loads Markdown entries from disk.
- A `ContentEntry` behaves like a lightweight model.
- `CaseStudy` and `Article` can grow domain-specific behavior.
- `MarkdownRenderer` owns Markdown-to-HTML rendering.
- Controllers ask repositories for entries and pass them to views.

The future path is straightforward. If I later want tags, search, RSS, sitemap generation, or an admin interface, the public controllers and views do not need to change much. The repository can start reading from ActiveRecord instead of files.

Production does not need to run Rails continuously. A GitHub Actions workflow boots the application, renders every published route through the real controllers and layouts, compiles the assets, validates internal links and files, and deploys the resulting static artifact to GitHub Pages.

That boundary keeps one rendering implementation while removing the application server, secrets, cold starts, and runtime cost from the public site. Rails is the build-time authoring framework; production is HTML, CSS, and images.

The lesson is not that every static site should use Rails. It is that Rails can be a simple tool when you use the parts you need and decline the parts you do not.


---

## SOURCE: content/writing/technical-disagreement-and-alternatives.md

---
title: Technical Disagreement and Alternatives
summary: How I adjust technical disagreement for peers, developing engineers, senior engineers, and business stakeholders.
date: 2026-07-11
order: 3
category: Collaboration
tags:
  - Product Engineering
  - Leadership
  - Architecture
  - Operations
status: published
---

I do not think raising a concern is the same as contributing a solution.

If I disagree with a proposed technical direction, I try to bring a clear alternative. Sometimes I can define it during the conversation. Sometimes the responsible answer is, "I think there is a risk here; give me a little time to verify it and I will follow up."

The important part is closing that loop quickly.

## Match the Conversation to the Person

The substance of a concern should remain consistent, but the way I introduce it depends on who owns the proposal.

With an engineer who is still developing, I am more likely to identify the concern and ask whether they see a solution that addresses it. That gives them room to reason through the consequences instead of replacing their work with mine.

With a senior engineer, I am more direct. I will put my alternative next to the proposal and ask how they see the tradeoff. The goal is not to perform deference or certainty. It is to expose assumptions while there is still time to change them.

With a business stakeholder, I translate the disagreement into results, risk, and resources. They do not need a lecture about framework internals. They need to know what each path makes possible, what it costs, and where it can fail.

## A Commerce Example

Consider a marketplace order containing products fulfilled by several independent Shopify stores.

One proposal is to transmit every brand order synchronously inside checkout. The argument is understandable: do not confirm success until every partner store has accepted its portion.

My concern would be that this makes payment and checkout depend on several external systems at once. One slow store could hold open a database transaction. One unavailable API could fail checkout after payment. A retry could repeat transmissions that already succeeded.

I would propose committing the Dogly order first and creating one independently retryable transmission job per brand.

That alone does not answer the stakeholder's concern. The product language has to change with the architecture.

Instead of telling the customer that every item is confirmed and on its way, confirm what is actually true:

> We received your Dogly order and are processing it. We will update you as each brand fulfills its shipment.

Customers already understand that one ecommerce order can produce several shipments and tracking emails. Dogly's legacy ShipStation workflow behaved that way, and large retailers routinely fulfill one order from a distribution center and multiple stores.

The alternative therefore includes both a safer technical boundary and a small product feature: an honest processing state followed by shipment-specific updates.

## Define the First Release

For an initial release, I would require:

- The Dogly order to commit independently of partner APIs.
- One transmission state per brand.
- An idempotency key and external order ID per transmission.
- Automatic retries for transient failures.
- An administrator-visible failure state and manual retry.
- Customer copy that distinguishes order receipt from fulfillment confirmation.
- Shipment updates as brands accept and fulfill their portions.

I would not require a fully generalized integration event platform before the first order. I would require enough state that a failed transmission cannot become invisible or duplicate a successful one.

## Disagreement Is Part of Product Design

The useful alternative is rarely "do the same feature with a different class structure."

Architecture changes what the product can truthfully promise. Product language can remove a false technical requirement. Existing customer expectations can make a safer workflow feel familiar rather than compromised.

That is what I try to bring to disagreement: not only a warning, but another path that connects engineering constraints back to the outcome everyone is trying to achieve.
