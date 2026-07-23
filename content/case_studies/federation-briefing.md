---
title: The Federation Briefing
summary: Turning a week of Star Trek community discussions into a sourced AI briefing that shows its work and knows when it does not have enough evidence.
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
