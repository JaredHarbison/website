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
