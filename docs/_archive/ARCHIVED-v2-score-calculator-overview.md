# SCORE Calculator — Algorithm & Methodology Overview

**For:** Gallup Partnership Team (Anna Siebert, Jamie Hunt, Brent Michels, Jordan Warnock, Dean Jones)
**Prepared by:** Silent Partners
**Date:** May 2026

---

## What the SCORE Calculator Does

The SCORE Calculator quantifies the true annual cost of a workplace friction point across five business dimensions — in real dollars, with benchmark comparisons — so executives see not just what something costs, but how far they are from acceptable and what it is doing to their growth. Participants apply it to each friction point they identify during the workshop, and the score updates in real time as they enter their data.

---

## The Five SCORE Dimensions

**S — Speed** | Time and velocity loss from the friction point
**C — Cost** | Direct financial waste: labor, tools, opportunity cost
**O — Operational** | Quality failures, rework, and capacity left idle
**R — Risk** | Incident exposure, key-person dependency, customer impact
**E — Earnings** | Revenue being left on the table due to constrained capacity or growth

Each dimension produces an **annual dollar figure**. The five figures sum to a **Total Size of Problem**.

---

## The Calculation Engine (How the Score Is Built)

Each friction point is scored by entering a small set of quantitative inputs. The formulas are exact — no subjective sliders.

### S — Speed
> **Annual Time Cost = Team Size × Hours/Person/Week × Loaded Hourly Rate × 52**

Inputs: number of people affected, hours per person per week on the friction
Rate: pulled from industry/profession benchmark for the workshop cohort

### C — Cost
> **Annual Cost = (Labor FTEs × Fully-Loaded FTE Cost) + Vendor/Tool Spend + Opportunity Cost**

Inputs: FTEs dedicated to the friction, annual tool costs, estimated opportunity cost
FTE cost rate: pulled from industry/profession benchmark

### O — Operational
> **Annual Efficiency Cost = Errors/Defects per Year × Cost per Error**

Inputs: annual process volume, number of defects/failures, cost per failure
Benchmark: world-class error rate is 2–3%; gaps are shown as a multiplier (e.g., "7x worse")

### R — Risk
> **Annual Risk Exposure = (Minor Incidents/Year × Cost Each) + (Major Incident Probability% × Major Incident Cost)**

Inputs: minor incident frequency and cost; probability and cost of a major incident
This captures both the current run-rate of incidents and the expected value of a tail event

### E — Earnings
> **Annual Revenue Constraint = Current Revenue × Additional Capacity Unlocked% × Contribution Margin%**

Inputs: current annual revenue, estimated capacity freed if friction is removed, contribution margin
This translates operational relief directly into growth potential

---

## Total Size of Problem & Severity Rating

```
Total Size of Problem = Speed + Cost + Operational + Risk + Earnings
```

The total drives an automatic **Severity Rating**:

| Total Annual Impact | Rating |
|---|---|
| Under $1M | Moderate friction |
| $1M – $3M | Major friction — priority build candidate |
| $3M – $5M | Critical friction — immediate action |
| $5M+ | Existential friction — emergency |

---

## How Industry & Profession Benchmarking Works

Before scoring begins, each workshop cohort is configured with benchmark data tied to the client's industry and profession. Two benchmark values anchor all calculations:

- **Loaded Hourly Rate** — used in Speed calculations
- **Fully-Loaded Cost per FTE** — used in Cost calculations

If no custom benchmarks are configured, the system falls back to conservative defaults. This means every score is calibrated to the client's context, not a generic average, and two companies in different industries scoring the same friction inputs will produce meaningfully different dollar outputs.

---

## Real-Time Scoring

The score calculates instantly as inputs are entered — there is no submit step. Partially completed dimensions are excluded from the total; they don't default to zero or inflate the score. Each friction point also carries a **Confidence Level** (High / Medium / Low) so participants can flag where estimates are solid versus where more discovery is needed before acting.

---

## What the Output Looks Like

For each friction point, the participant sees:

- Dollar contribution from each of the five SCORE dimensions
- **Total Size of Problem** (annual)
- **Severity Rating** (Moderate → Existential)
- **Primary Driver** — which dimension accounts for the largest share of the total
- A shareable report link that can be distributed to stakeholders

---

## Three Numbers That Matter to an Executive

The rubric is built around a core insight: executives don't act on dollar amounts alone. Each SCORE dimension delivers three numbers that together make the problem undeniable:

1. **The financial cost** — what it costs annually
2. **The performance gap** — how far from benchmark or world-class
3. **The strategic impact** — as a % of budget, revenue, capacity, or risk exposure

For example, a friction point scoring $4.9M total would be presented as:
- *"You're 7x slower than industry standard on this process"* (Speed gap)
- *"You're burning 18% of your department budget on one friction point"* (Cost impact)
- *"There's a 55% chance of a $1.2M compliance incident in the next 12 months"* (Risk exposure)

---

## Connection to Gallup's Work

SCORE measures the **operational cost** of friction — what it is doing to time, money, quality, risk, and growth. Gallup's Q12 measures the **human cost** — what that friction is doing to engagement and the conditions people need to do their best work.

Used together:
- **Gallup Q12** → where engagement is breaking down and why
- **SCORE** → what that breakdown is costing in dollars, and which friction points to fix first

The Earnings (E) dimension is the most natural bridge: it converts people-level friction directly into revenue impact, which is the language that moves executive action.

---

*Source: Silent Partners `sp-workshop-v2` — `frictionScoreRubrics.ts`, `Silent Partners Friction SCORE Rubric` (Google Drive)*
