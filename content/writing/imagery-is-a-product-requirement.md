---
title: Imagery Can Be a Product Requirement
navigation_title: Imagery Is a Product Requirement
summary: Performance matters, but removing the visual quality users value is not automatically an optimization.
date: 2026-07-11
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
