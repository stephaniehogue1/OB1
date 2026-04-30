# SCORE Calculator — Algorithm & Methodology Overview

**For:** Gallup Partnership Team (Anna Siebert, Jamie Hunt, Brent Michels, Jordan Warnock, Dean Jones)
**Prepared by:** Silent Partners
**Date:** May 2026

---

## What the SCORE Calculator Does

The SCORE Calculator quantifies the real cost of workplace friction — in dollars and hours — for individual clients, benchmarked against their industry and profession. As a client works through ten friction-point questions, their score assembles in real time, giving them an immediate, tangible picture of what inefficiency is actually costing their organization.

---

## The Five SCORE Dimensions

SCORE is a composite of five measurable friction categories. Each dimension captures a distinct class of loss:

| Dimension | What It Measures |
|-----------|-----------------|
| **S — Speed** | Velocity loss: delays, wait time, slow handoffs, re-work cycles |
| **C — Cost** | Direct financial waste: redundant spend, manual workarounds, over-resourcing |
| **O — Operational** | Process friction: broken workflows, approval bottlenecks, tool misalignment |
| **R — Risk** | Exposure from friction: compliance gaps, errors from rushed or unclear handoffs |
| **E — Engagement** | People friction: disengagement tax, talent drag, morale erosion from systemic friction |

---

## How the Score Is Built: Step by Step

### 1. Industry & Profession Selection
Before any questions are answered, the client selects their **industry** and **profession**. This loads a benchmark dataset that calibrates what "normal" friction looks like for their peer group — so their final score is relative, not just absolute.

### 2. Ten Friction-Point Questions
The client moves through a guided 10-question input wizard. Each question targets a specific friction behavior and maps to one or more SCORE dimensions. Questions are designed to be answerable in concrete, operational terms — not abstract ratings. Examples include:

- How much time per week is spent re-explaining context to colleagues or vendors?
- How many approval steps does a standard decision require?
- What is the monthly cost of tools that duplicate each other's function?

### 3. Time-Unit Normalization
Inputs are accepted in the unit most natural to the client (per day, per week, per month). The engine normalizes all inputs to an **annual equivalent** before scoring:

- Per-month inputs → × 12
- Per-week inputs → converted to hours or days, then annualized
- Per-day inputs → × working days per year (~230)

This ensures all five dimension scores are on a consistent annual basis regardless of how the client entered their data.

### 4. Dimension Score Calculation
Each dimension module converts normalized inputs into a **dollar-impact value** using:

```
Dimension Score = (Time Lost × Loaded Hourly Rate) + Direct Spend Waste + Risk-Adjusted Exposure
```

- **Speed & Operational** scores are primarily time-based (hours lost × role cost)
- **Cost** scores are primarily spend-based (redundant tools, workarounds)
- **Risk** scores apply a probability-weighted exposure factor to error-prone friction points
- **Engagement** scores use a disengagement multiplier derived from Gallup's engagement-productivity research (productivity loss per disengaged employee at a given friction level)

### 5. Composite SCORE Assembly
The five dimension scores are summed and weighted into a single **Total SCORE**:

```
Total SCORE = Σ (Dimension Score × Dimension Weight)
```

Default dimension weights reflect average organizational impact across industries. Weights shift slightly based on the selected **industry** (e.g., regulated industries weight Risk higher; service-heavy industries weight Engagement and Speed higher).

### 6. Benchmark Comparison
The Total SCORE is plotted against the **industry + profession benchmark band** loaded in Step 1. The client sees:

- Their raw annual friction cost (dollar figure)
- Their percentile position relative to peers in the same industry/profession
- Which dimension is driving the most friction

---

## Real-Time Scoring

The score updates with each answered question. Clients do not need to complete all ten questions to see a meaningful score — the engine runs partial calculations as inputs arrive, filling unanswered dimensions with benchmark averages as placeholders. This keeps the dashboard live and actionable from the first answer.

---

## Output Views

**Friction Dashboard** — Visual breakdown of each SCORE dimension, showing the dollar contribution of each friction category and how it compares to the industry benchmark.

**Engagement Summary** — Surfaces the human-layer cost specifically: the engagement dimension translated into headcount-equivalent productivity loss, relevant for talent strategy conversations.

---

## Why This Matters for Gallup

The **Engagement (E)** dimension of SCORE is structurally aligned with Gallup's Q12 engagement framework. Where Gallup measures the *presence or absence* of engagement conditions, SCORE measures the *friction that drives disengagement*. Together, they offer:

- Gallup Q12 → **What the engagement level is**
- SCORE Calculator → **What is causing it and what it costs**

This creates a natural diagnostic pairing: SCORE surfaces the friction picture; Gallup's methodology provides the intervention framework.

---

*Source: Silent Partners `impact-score` application — `score-friction-calculator v1.0.0`*
