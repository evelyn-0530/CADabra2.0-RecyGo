"""
RecyGo Digital Simulation Model
================================
Southeast Asia Engineering Design Competition 2026 - Deliverable 2

Models a district of 500 households + 20 commercial units over 30 days,
comparing a BASELINE (no AI, fixed-schedule collection, manual sorting)
scenario against an AI-ENABLED (RecyGo) scenario with:
  - AI waste classification (conveyor + camera sorting -> lower contamination)
  - Smart bin monitoring (ultrasonic fill sensors -> threshold-based collection)

Run this in Google Colab or locally with: pip install matplotlib numpy scipy
"""

import numpy as np
import matplotlib.pyplot as plt
import random
import time

# ============================================================
# CONFIGURATION PARAMETERS
# ============================================================

random.seed(42)
np.random.seed(42)

SIM_DAYS = 30
N_HOUSEHOLDS = 500
N_COMMERCIAL = 20

# Waste generation (kg/day), roughly based on typical urban waste stats
HOUSEHOLD_WASTE_MEAN = 1.2   # kg/household/day
HOUSEHOLD_WASTE_STD = 0.3
COMMERCIAL_WASTE_MEAN = 15.0  # kg/unit/day (commercial produces more)
COMMERCIAL_WASTE_STD = 4.0

# Waste composition (fraction of total waste stream)
WASTE_CATEGORIES = ["plastic", "paper", "general"]
CATEGORY_SPLIT = {"plastic": 0.30, "paper": 0.25, "general": 0.45}

# Bin capacity per category, per "cluster" (one 3-bin unit per HOUSEHOLDS_PER_CLUSTER households)
HOUSEHOLDS_PER_CLUSTER = 50
COMMERCIAL_PER_CLUSTER = 2
N_CLUSTERS = max(N_HOUSEHOLDS // HOUSEHOLDS_PER_CLUSTER,
                  N_COMMERCIAL // COMMERCIAL_PER_CLUSTER)
BIN_CAPACITY_KG = 90  # kg capacity per category bin, based on the physical prototype's compartment size

# Contamination rates (probability a discarded item goes into WRONG bin)
# BASELINE: ~25% of items placed in household recycling bins are misclassified/contaminated,
# per The Recycling Partnership (2024) industry report — cited in Ecorithms, "Recycling
# Contamination: Cost, Impact, and Fixes" (2025), https://ecorithms.com/blog/recycling-contamination
# Other academic studies (e.g. Calder & co., California Management Review, 2023) found even
# higher error rates for ambiguous item categories — 25% is the more conservative, defensible figure.
BASELINE_CONTAMINATION = 0.25
# AI: from the team's own trained YOLO model (Roboflow), tested on a labelled validation set —
# overall_ai_accuracy = 0.86 across plastic/paper/metal categories (per-category accuracy was
# identical at 0.86 in the test results, so a single rate is used here)
AI_CONTAMINATION = 0.14

# Collection logic
BASELINE_COLLECTION_INTERVAL_DAYS = 3   # fixed schedule regardless of fill level (a typical
                                         # municipal "collect every 3 days" routine, independent of actual fill)
AI_FILL_THRESHOLD = 0.90                # AI system dispatches truck only when bin >= 90% full

# CO2 / cost estimates
# CO2_PER_TRIP_KG: derived from a real urban waste-collection zone dataset — 36 collection
# routes covering 708.0 km, consuming 118.0 L diesel, emitting 273.77 kg CO2 total
# (273.77 / 36 ≈ 7.6 kg CO2 per route). Source: "An emission-capacitated vehicle routing
# model for sustainable urban waste collection using hybrid guided local search",
# Scientific Reports / PMC (2026). The source's "route" represents a full zone service run,
# which may cover more ground than a single cluster visit in this model — this figure is
# therefore treated as an order-of-magnitude reference rather than an exact match to the
# district's fleet/route length.
CO2_PER_TRIP_KG = 7.6
# COST_PER_TRIP: from the SAME study as CO2_PER_TRIP_KG (consistent source, same 36 routes) —
# reported operational cost of 133.99 USD for the 36-route zone (133.99 / 36 ≈ 3.72 USD/trip).
# This figure covers fuel and carbon cost only, as reported in the source; it excludes
# labour/wages, vehicle maintenance, and depreciation, and therefore understates full
# operating cost. A complete cost estimate including labour would require an additional
# labour-cost-share figure from a separate source.
# Converted to Malaysian Ringgit at 1 USD = 4.086 MYR (Xe.com mid-market rate, 2 Aug 2026).
# Exchange rates fluctuate over time.
USD_TO_MYR = 4.086
COST_PER_TRIP = 3.72 * USD_TO_MYR   # RM per trip, fuel + carbon cost only (see note above)
CURRENCY_LABEL = "RM"

# LANDFILL_EMISSION_FACTOR: applies only to waste actually LOST to overflow (spilled/uncollected,
# never captured for proper recycling -> assumed landfill-bound instead). 779.78 kg CO2-equivalent
# per tonne of MSW landfilled (~0.78 kg CO2e/kg), from Ho Chi Minh City MSW GHG study, MDPI
# Recycling 2022, https://www.mdpi.com/2413-8851/6/4/78. NOTE: this factor represents total
# lifetime landfill decomposition (mostly methane, converted to CO2-equivalent), NOT a
# "per day sitting in an overflowing bin" rate — it is applied here as the emissions cost of
# that kg's ultimate fate (landfill) rather than a short-term daily process.
LANDFILL_EMISSION_FACTOR = 0.78  # kg CO2e per kg waste landfilled

# ============================================================
# BIN CLASS
# ============================================================

class BinCluster:
    """Represents one 3-bin unit (plastic/paper/general) serving a group of households."""
    def __init__(self, cluster_id):
        self.id = cluster_id
        self.levels = {cat: 0.0 for cat in WASTE_CATEGORIES}  # kg currently in each bin
        self.overflow_events = {cat: 0 for cat in WASTE_CATEGORIES}
        self.overflow_kg = {cat: 0.0 for cat in WASTE_CATEGORIES}  # kg actually lost/spilled
        self.collections = 0

    def add_waste(self, category, amount):
        self.levels[category] += amount
        if self.levels[category] > BIN_CAPACITY_KG:
            excess = self.levels[category] - BIN_CAPACITY_KG
            self.overflow_events[category] += 1
            self.overflow_kg[category] += excess
            # excess waste is "lost" / dumped illegally - not collected, not recycled
            self.levels[category] = BIN_CAPACITY_KG

    def fill_fraction(self, category):
        return self.levels[category] / BIN_CAPACITY_KG

    def collect(self):
        self.levels = {cat: 0.0 for cat in WASTE_CATEGORIES}
        self.collections += 1


# ============================================================
# WASTE GENERATION
# ============================================================

def generate_daily_waste(n_households, n_commercial):
    """Returns total kg of waste generated today across the whole district."""
    household_total = np.sum(np.random.normal(HOUSEHOLD_WASTE_MEAN, HOUSEHOLD_WASTE_STD, n_households).clip(min=0))
    commercial_total = np.sum(np.random.normal(COMMERCIAL_WASTE_MEAN, COMMERCIAL_WASTE_STD, n_commercial).clip(min=0))
    return household_total + commercial_total


def distribute_to_clusters(total_kg, clusters, contamination_rate):
    """Split today's waste across clusters and categories, applying misclassification."""
    per_cluster_kg = total_kg / len(clusters)
    for cluster in clusters:
        for true_category in WASTE_CATEGORIES:
            amount = per_cluster_kg * CATEGORY_SPLIT[true_category]
            if random.random() < contamination_rate:
                # misclassified: dumped into a random OTHER bin
                wrong_choices = [c for c in WASTE_CATEGORIES if c != true_category]
                bin_used = random.choice(wrong_choices)
            else:
                bin_used = true_category
            cluster.add_waste(bin_used, amount)


# ============================================================
# SIMULATION RUN
# ============================================================

def run_simulation(scenario="baseline", verbose=False, pace_seconds=0.0):
    """
    scenario: "baseline" or "ai"
    verbose: if True, prints a line for each simulated day (good for recording a demo video)
    pace_seconds: if >0, pauses this many seconds between days so the printout is
                  actually watchable on screen instead of flashing by instantly
    Returns a dict of daily KPI tracking + summary totals.
    """
    clusters = [BinCluster(i) for i in range(N_CLUSTERS)]
    contamination_rate = BASELINE_CONTAMINATION if scenario == "baseline" else AI_CONTAMINATION

    daily_overflow = []
    daily_trips = []
    cumulative_trips = 0
    cumulative_overflow = 0
    cumulative_overflow_kg = 0.0

    if verbose:
        label = "BASELINE (no AI)" if scenario == "baseline" else "AI-ENABLED (RecyGo)"
        print(f"\n--- Running {label} scenario over {SIM_DAYS} days ---")

    for day in range(1, SIM_DAYS + 1):
        # 1. Generate + distribute today's waste
        total_waste = generate_daily_waste(N_HOUSEHOLDS, N_COMMERCIAL)
        distribute_to_clusters(total_waste, clusters, contamination_rate)

        # 2. Collection decision
        trips_today = 0
        if scenario == "baseline":
            # fixed schedule: collect ALL clusters every N days, regardless of fill level
            if day % BASELINE_COLLECTION_INTERVAL_DAYS == 0:
                for cluster in clusters:
                    cluster.collect()
                    trips_today += 1  # one trip per cluster visited
        else:
            # AI: only collect clusters where any bin >= threshold
            for cluster in clusters:
                if any(cluster.fill_fraction(cat) >= AI_FILL_THRESHOLD for cat in WASTE_CATEGORIES):
                    cluster.collect()
                    trips_today += 1

        # 3. Track overflow events + kg lost that happened today (reset counters after reading)
        overflow_today = sum(sum(c.overflow_events.values()) for c in clusters)
        overflow_kg_today = sum(sum(c.overflow_kg.values()) for c in clusters)
        for c in clusters:
            c.overflow_events = {cat: 0 for cat in WASTE_CATEGORIES}
            c.overflow_kg = {cat: 0.0 for cat in WASTE_CATEGORIES}

        cumulative_trips += trips_today
        cumulative_overflow += overflow_today
        cumulative_overflow_kg += overflow_kg_today
        daily_overflow.append(overflow_today)
        daily_trips.append(trips_today)

        if verbose:
            avg_fill = np.mean([cluster.fill_fraction(cat)
                                 for cluster in clusters for cat in WASTE_CATEGORIES]) * 100
            print(f"Day {day:>2}: waste generated={total_waste:6.1f} kg | "
                  f"trips today={trips_today:2} | overflow today={overflow_today:2} | "
                  f"avg bin fill={avg_fill:5.1f}%")
            if pace_seconds > 0:
                time.sleep(pace_seconds)

    recycling_accuracy = 1 - contamination_rate  # simple proxy KPI
    truck_co2_kg = cumulative_trips * CO2_PER_TRIP_KG
    decomposition_co2_kg = cumulative_overflow_kg * LANDFILL_EMISSION_FACTOR

    return {
        "scenario": scenario,
        "daily_overflow": daily_overflow,
        "daily_trips": daily_trips,
        "total_trips": cumulative_trips,
        "total_overflow": cumulative_overflow,
        "total_overflow_kg": cumulative_overflow_kg,
        "recycling_accuracy": recycling_accuracy,
        "truck_co2_kg": truck_co2_kg,
        "decomposition_co2_kg": decomposition_co2_kg,
        "total_co2_kg": truck_co2_kg + decomposition_co2_kg,
        "total_cost": cumulative_trips * COST_PER_TRIP,
    }


# ============================================================
# RUN BOTH SCENARIOS + COMPARE
# ============================================================

# Set PACE_SECONDS > 0 (e.g. 0.15) if screen-recording, so each day's line is
# actually visible instead of printing all 30 days instantly. Set to 0 for a fast run.
PACE_SECONDS = 0.15

baseline_results = run_simulation("baseline", verbose=True, pace_seconds=PACE_SECONDS)
ai_results = run_simulation("ai", verbose=True, pace_seconds=PACE_SECONDS)

print("=" * 55)
print(f"{'METRIC':<28}{'BASELINE':>12}{'AI-ENABLED':>15}")
print("=" * 55)
print(f"{'Total collection trips':<28}{baseline_results['total_trips']:>12}{ai_results['total_trips']:>15}")
print(f"{'Total overflow incidents':<28}{baseline_results['total_overflow']:>12}{ai_results['total_overflow']:>15}")
print(f"{'Waste lost to overflow (kg)':<28}{baseline_results['total_overflow_kg']:>12.1f}{ai_results['total_overflow_kg']:>15.1f}")
print(f"{'Recycling accuracy':<28}{baseline_results['recycling_accuracy']*100:>11.1f}%{ai_results['recycling_accuracy']*100:>14.1f}%")
print(f"{'  Truck CO2 (kg)':<28}{baseline_results['truck_co2_kg']:>12.1f}{ai_results['truck_co2_kg']:>15.1f}")
print(f"{'  Decomposition CO2 (kg)':<28}{baseline_results['decomposition_co2_kg']:>12.1f}{ai_results['decomposition_co2_kg']:>15.1f}")
print(f"{'Total CO2 (kg)':<28}{baseline_results['total_co2_kg']:>12.1f}{ai_results['total_co2_kg']:>15.1f}")
print(f"{'Total cost (' + CURRENCY_LABEL + ')':<28}{baseline_results['total_cost']:>12.1f}{ai_results['total_cost']:>15.1f}")
print("=" * 55)

trips_saved = baseline_results['total_trips'] - ai_results['total_trips']
co2_reduced = baseline_results['total_co2_kg'] - ai_results['total_co2_kg']
overflow_reduction_pct = (1 - ai_results['total_overflow'] / max(baseline_results['total_overflow'], 1)) * 100

print(f"\nCollection trips saved: {trips_saved} ({trips_saved/baseline_results['total_trips']*100:.1f}%)")
print(f"CO2 reduced: {co2_reduced:.1f} kg")
print(f"Overflow reduction: {overflow_reduction_pct:.1f}%")

# ============================================================
# STATISTICAL COMPARISON (baseline vs AI, two KPIs)
# ============================================================
from scipy import stats

t_trips, p_trips = stats.ttest_ind(baseline_results['daily_trips'], ai_results['daily_trips'])
t_overflow, p_overflow = stats.ttest_ind(baseline_results['daily_overflow'], ai_results['daily_overflow'])

print(f"\nt-test on daily trips:    t={t_trips:.2f}, p={p_trips:.4f}"
      + ("  -> significant difference" if p_trips < 0.05 else "  -> not statistically significant"))
print(f"t-test on daily overflow: t={t_overflow:.2f}, p={p_overflow:.4f}"
      + ("  -> significant difference" if p_overflow < 0.05 else "  -> not statistically significant"))
print("(p < 0.05 means the baseline vs AI difference is unlikely to be due to random chance)")

# ============================================================
# PLOTS
# ============================================================

fig, axes = plt.subplots(2, 2, figsize=(12, 9))

days_range = list(range(1, SIM_DAYS + 1))

# Cumulative overflow
axes[0, 0].plot(days_range, np.cumsum(baseline_results['daily_overflow']), label="Baseline", marker='o', markersize=3)
axes[0, 0].plot(days_range, np.cumsum(ai_results['daily_overflow']), label="AI-enabled", marker='o', markersize=3)
axes[0, 0].set_title("Cumulative Overflow Incidents")
axes[0, 0].set_xlabel("Day")
axes[0, 0].set_ylabel("Incidents")
axes[0, 0].legend()

# Cumulative trips
axes[0, 1].plot(days_range, np.cumsum(baseline_results['daily_trips']), label="Baseline", marker='o', markersize=3)
axes[0, 1].plot(days_range, np.cumsum(ai_results['daily_trips']), label="AI-enabled", marker='o', markersize=3)
axes[0, 1].set_title("Cumulative Collection Trips")
axes[0, 1].set_xlabel("Day")
axes[0, 1].set_ylabel("Trips")
axes[0, 1].legend()

# Recycling accuracy bar
axes[1, 0].bar(["Baseline", "AI-enabled"],
               [baseline_results['recycling_accuracy']*100, ai_results['recycling_accuracy']*100],
               color=["gray", "green"])
axes[1, 0].set_title("Recycling Accuracy (%)")
axes[1, 0].set_ylabel("%")
axes[1, 0].set_ylim(60, 90)

# CO2 comparison bar - stacked to show truck vs decomposition emissions separately
scenarios = ["Baseline", "AI-enabled"]
truck_vals = [baseline_results['truck_co2_kg'], ai_results['truck_co2_kg']]
decomp_vals = [baseline_results['decomposition_co2_kg'], ai_results['decomposition_co2_kg']]
axes[1, 1].bar(scenarios, truck_vals, label="Truck (collection trips)", color=["gray", "green"])
axes[1, 1].bar(scenarios, decomp_vals, bottom=truck_vals,
               label="Decomposition (waste lost to overflow)", color=["lightgray", "lightgreen"],
               hatch="//")
axes[1, 1].set_title("Total CO2 Emissions (kg, 30 days)")
axes[1, 1].set_ylabel("kg CO2")
axes[1, 1].legend(fontsize=8)

plt.tight_layout()
plt.savefig("recygo_simulation_results.png", dpi=150)
plt.show()

print("\nSaved chart to recygo_simulation_results.png")
