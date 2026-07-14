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
