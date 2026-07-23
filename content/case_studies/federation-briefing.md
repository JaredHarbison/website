---
title: The Federation Briefing
summary: Building a reproducible RAG briefing that makes retrieval, evidence, abstention, and the value of context visible instead of hiding them behind an AI-generated answer.
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

[The Federation Briefing](https://github.com/JaredHarbison/the-federation-briefing) is a small retrieval-augmented generation application that turns a week of public Star Trek community discussions into an evidence-linked briefing.

I built it to explore a more useful question than whether an LLM can summarize text: can a reviewer see what the system retrieved, which claims depend on which sources, when the system lacks enough evidence, and what retrieval adds compared with the same model operating without current context?

The result is a Streamlit application with a command-driven ingestion workflow, local and OpenAI embedding paths, diversified retrieval, claim-level source labels, an explicit no-context control, and a reproducible offline mode.

## Problem

A fluent weekly report can sound current and authoritative even when it is based on weak retrieval or no current evidence at all. A conventional demo often hides that risk by presenting only the generated answer.

For a community briefing, I wanted the evidence boundary to remain visible. The application needed to distinguish observations from forecasts, connect community claims to specific discussions, and refuse custom questions that the weekly corpus could not support.

It also needed to remain reviewable without sharing an API key. An evaluator should be able to clone the repository, run the application, inspect real source records, exercise retrieval, and compare a genuine keyed result without incurring API usage.

## Context

This is a focused portfolio prototype, not a production analytics service. The reviewed snapshot contains up to 25 public `r/startrek` discussions from one seven-day window. Streamlit provides the analyst interface, while Python modules and scripts own ingestion, retrieval, generation, snapshot promotion, and canonical artifact generation.

The project supports two operating modes:

- A deterministic local path uses TF-IDF vectors and fallback reports.
- A keyed path uses OpenAI embeddings and chat generation.

For the default analyst question, the repository includes a reviewed OpenAI-generated baseline/RAG pair. That artifact makes the full comparison visible in the no-key experience without exposing my credential.

## Constraints

- Never send an API key to the browser or commit it to the repository.
- Preserve a usable, reproducible evaluator experience without paid API access.
- Use only retrieved discussions as evidence for current community claims.
- Keep the baseline isolated from posts, dates, source titles, and retrieval results.
- Abstain when a custom focus is not supported by the weekly corpus.
- Survive blocked Reddit JSON requests through a public RSS fallback.
- Prevent a failed or malformed live fetch from silently replacing reviewed demo data.
- Keep the implementation small enough for an evaluator to understand quickly.

## My Role

I designed and implemented the complete prototype: ingestion, snapshot lifecycle, local vector representation, OpenAI integration, retrieval policies, evidence prompts, unsupported-query gate, deterministic fallbacks, A/B interface, retrieval diagnostics, and tests.

I also defined the evaluation contract. Both report conditions use the same five-section schema, while the control receives no current context and the RAG condition receives only selected evidence. This makes access to retrieved context the main changed variable.

## Approach

I separated the workflow into four boundaries: acquire and review source data, build a vector representation, select evidence, and generate or display a report.

![The Federation Briefing pipeline from reviewed community data through retrieval and evidence-linked reporting](/images/federation-briefing-pipeline.svg)

Live ingestion writes to an ignored working file rather than replacing the committed snapshot. A separate promotion command validates required fields, timestamps, and specific Reddit discussion URLs, and requires an explicit confirmation flag. The reviewed snapshot then feeds both the offline vector store and the optional OpenAI embedding path.

For the weekly briefing, one broad similarity query was not enough. It tended to favor whichever topic dominated the small corpus. I introduced five retrieval lenses:

- The analyst's stated focus.
- Releases and upcoming events.
- Debates and criticism.
- Newcomer questions.
- Creative participation.

The selector ranks documents for each lens, adds a small engagement weight, then chooses round-robin across the ranked lists while deduplicating results. The final evidence set is capped at eight posts.

## Technical Implementation

The local path builds TF-IDF document vectors with scikit-learn. Titles are repeated in the indexed document text so concise topic labels retain influence beside longer post bodies. When an API key is present, the same documents and query lenses use the configured OpenAI embedding model instead.

Each selected record carries its similarity score and the lens that retrieved it. The Streamlit interface exposes those details in source cards next to the report and labels similarity correctly as alignment to a retrieval lens, not confidence or factual accuracy.

The RAG prompt receives only the selected posts, labeled `S1` through `S8`. It requires a citation in every substantive paragraph, forbids invented counter-positions, asks the model to label forecasts as inferences, and instructs it to omit claims that its cited source does not support.

The baseline uses the same report headings but receives no community documents, dates, sources, or retrieval results. Its prompt requires conditional language and prevents it from presenting evergreen model knowledge as a current observation.

Custom questions pass through an evidence gate before generation. The system extracts meaningful subject terms, checks their coverage in the corpus, and applies a conservative cosine-similarity threshold. If either check fails, it returns a structured insufficient-evidence report with no citations instead of asking the model to improvise from unrelated posts.

The no-key experience still exercises real local retrieval. For the default question it additionally loads the reviewed canonical OpenAI artifact, whose generation script validates the shared heading schema, RAG citations, and baseline isolation before writing it.

Tests cover snapshot structure, relevant retrieval, diversified release coverage, unsupported and supported custom questions, baseline isolation, source labels, matching A/B schemas, and the seven-day ingestion boundary.

## Tradeoffs

The corpus is deliberately small and represents one subreddit over one week. It is useful for demonstrating the system, but it cannot support claims about the broader Star Trek audience. Reddit scores also provide only a light ranking signal; they are not a measure of representativeness.

The evidence gate combines simple stemming, lexical coverage, and hand-selected semantic thresholds. This is understandable and testable, but it is not a calibrated relevance classifier. A larger corpus would need evaluation data and threshold tuning based on labeled queries.

The local query representation is simpler than the indexed TF-IDF representation, and the vector store and retrieval counters are JSON files. Those choices make the demo portable, but they are not appropriate for concurrent users or a growing corpus.

The five retrieval lenses encode an editorial definition of a useful weekly briefing. They improve coverage, but they can also reserve space for a weakly supported category. A production version should measure marginal evidence quality before forcing diversity.

Finally, ingestion and snapshot promotion are command-driven. There is no production scheduler, hosted application, moderation workflow, or durable job system.

## Outcome

The finished prototype makes the full RAG path inspectable. An evaluator can see the selected sources, the reason each one was selected, the context-free control, the evidence-grounded report, retrieval frequency, and a two-dimensional embedding map in one interface.

It also remains useful in three failure conditions: without an API key, when OpenAI generation is unavailable, and when a custom question has insufficient evidence. In each case the application changes behavior explicitly instead of quietly presenting an ungrounded answer.

The most important result is the evaluation design. By holding the report schema and analyst question constant while removing current evidence from the baseline, the application demonstrates what retrieval contributes: current context, inspectable sources, a basis for claims, and a bounded basis for forecasts.

## What I'd Improve Today

I would build a labeled evaluation set of supported and unsupported analyst questions, then report retrieval precision, source coverage, citation correctness, and abstention quality. The current tests protect intended examples, but they do not measure performance across a representative query set.

I would replace local JSON state with a small database and store ingestion runs, documents, retrieval events, generated claims, and model configuration separately. That would support concurrent sessions, reproducible runs, and comparisons across multiple weeks.

I would add a scheduled ingestion job with rate-limit handling, content normalization, deduplication, and a review queue before publication. I would also expand beyond one community source so the briefing could describe its sample precisely without implying that one subreddit represents an entire fandom.

Finally, I would evaluate citations after generation at the claim level instead of relying only on prompt instructions and section-level citation checks. A useful next step would parse claims and cited source IDs, run an entailment check, and flag unsupported sentences for review before a briefing could be published.
