"""Problem 1: Smart Home Energy Consumption using a Bayesian Network.

Self-contained implementation (numpy / pandas / networkx / matplotlib):
exact inference by joint enumeration, ancestral sampling, MLE and BDeu estimation.
Run:  python problem1_bayesnet.py [A|B|C|DE|all]
"""
import itertools
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import pandas as pd

SEED = 42
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "outputs")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- structure
STATES = {
    "Weather": ["Hot", "Mild", "Cold"],
    "DayType": ["Weekday", "Weekend"],
    "Occupancy": ["High", "Low"],
    "AC": ["On", "Off"],
    "Load": ["Heavy", "Light"],
    "Energy": ["High", "Low"],
}
PARENTS = {
    "Weather": [], "DayType": [],
    "Occupancy": ["DayType"],
    "AC": ["Weather", "Occupancy"],
    "Load": ["Occupancy"],
    "Energy": ["AC", "Load"],
}
ORDER = ["Weather", "DayType", "Occupancy", "AC", "Load", "Energy"]  # topological

# Expert CPTs: dict  parent-state-tuple -> list of probabilities over STATES[var]
def p2(p):  # binary helper: [p, 1-p]
    return [p, 1 - p]

EXPERT = {
    "Weather": {(): [0.50, 0.30, 0.20]},
    "DayType": {(): [0.70, 0.30]},
    "Occupancy": {("Weekday",): p2(0.45), ("Weekend",): p2(0.80)},
    "AC": {("Hot", "High"): p2(0.90), ("Hot", "Low"): p2(0.60),
           ("Mild", "High"): p2(0.40), ("Mild", "Low"): p2(0.15),
           ("Cold", "High"): p2(0.10), ("Cold", "Low"): p2(0.05)},
    "Load": {("High",): p2(0.75), ("Low",): p2(0.35)},
    "Energy": {("On", "Heavy"): p2(0.92), ("On", "Light"): p2(0.68),
               ("Off", "Heavy"): p2(0.55), ("Off", "Light"): p2(0.12)},
}


def check_cpts(cpts, name):
    ok = True
    for v in ORDER:
        configs = list(itertools.product(*[STATES[p] for p in PARENTS[v]]))
        for c in configs:
            if c not in cpts[v]:
                print(f"  [{name}] {v}: missing parent configuration {c}"); ok = False; continue
            s = sum(cpts[v][c])
            if not np.isclose(s, 1.0):
                print(f"  [{name}] {v} | {c}: sums to {s}"); ok = False
    print(f"CPT validation ({name}): {'PASS - every distribution sums to 1' if ok else 'FAIL'}")
    return ok


# ---------------------------------------------------------------- inference
class BN:
    def __init__(self, cpts):
        self.cpts = cpts
        self.joint = {}
        for combo in itertools.product(*[STATES[v] for v in ORDER]):
            a = dict(zip(ORDER, combo))
            p = 1.0
            for v in ORDER:
                pc = tuple(a[q] for q in PARENTS[v])
                p *= cpts[v][pc][STATES[v].index(a[v])]
            self.joint[combo] = p

    def prob(self, query, evidence=None):
        """P(query | evidence); both are dicts var->state."""
        evidence = evidence or {}
        num = den = 0.0
        for combo, p in self.joint.items():
            a = dict(zip(ORDER, combo))
            if all(a[k] == s for k, s in evidence.items()):
                den += p
                if all(a[k] == s for k, s in query.items()):
                    num += p
        return num / den if den > 0 else float("nan")


QUERIES = {
    "Q1": ("P(E=High)", {"Energy": "High"}, {}),
    "Q2": ("P(E=High | W=Hot)", {"Energy": "High"}, {"Weather": "Hot"}),
    "Q3": ("P(E=High | D=Weekend)", {"Energy": "High"}, {"DayType": "Weekend"}),
    "Q4": ("P(E=High | W=Cold, O=High)", {"Energy": "High"}, {"Weather": "Cold", "Occupancy": "High"}),
    "Q5": ("P(W=Hot | E=High)", {"Weather": "Hot"}, {"Energy": "High"}),
    "Q6": ("P(AC=On | E=High)", {"AC": "On"}, {"Energy": "High"}),
    "Q7": ("P(AC=On | E=High, L=Heavy)", {"AC": "On"}, {"Energy": "High", "Load": "Heavy"}),
}


def run_queries(bn):
    return {q: bn.prob(qq, ev) for q, (_, qq, ev) in QUERIES.items()}


# ---------------------------------------------------------------- sampling
def ancestral_sample(cpts, n, seed):
    rng = np.random.default_rng(seed)
    rows = []
    for _ in range(n):
        a = {}
        for v in ORDER:                      # topological order
            pc = tuple(a[q] for q in PARENTS[v])
            a[v] = STATES[v][rng.choice(len(STATES[v]), p=cpts[v][pc])]
        rows.append(a)
    return pd.DataFrame(rows, columns=ORDER)


# ---------------------------------------------------------------- learning
def learn(df, method, ess=10):
    cpts = {}
    for v in ORDER:
        r = len(STATES[v])
        configs = list(itertools.product(*[STATES[p] for p in PARENTS[v]]))
        q = len(configs)
        cpts[v] = {}
        for c in configs:
            mask = np.ones(len(df), dtype=bool)
            for p, s in zip(PARENTS[v], c):
                mask &= (df[p] == s).values
            counts = np.array([(df[v][mask] == s).sum() for s in STATES[v]], dtype=float)
            if method == "MLE":
                tot = counts.sum()
                cpts[v][c] = list(counts / tot) if tot > 0 else [1.0 / r] * r
            else:  # BDeu: pseudo-count ESS/(r*q) per cell
                alpha = ess / (r * q)
                cpts[v][c] = list((counts + alpha) / (counts.sum() + r * alpha))
    return cpts


# ---------------------------------------------------------------- main
def draw_network():
    g = nx.DiGraph([(p, v) for v in ORDER for p in PARENTS[v]])
    pos = {"Weather": (0, 2), "DayType": (3, 2), "Occupancy": (3, 1), "AC": (1, 0.5),
           "Load": (4.5, 0.5), "Energy": (2.8, -0.7)}
    plt.figure(figsize=(8, 5))
    nx.draw(g, pos, with_labels=True, node_color="#cfe3f7", node_size=3200,
            font_size=9, arrowsize=20, edge_color="#444")
    plt.title("Smart Home Energy Bayesian Network")
    plt.savefig(os.path.join(OUT, "network.png"), dpi=150, bbox_inches="tight")
    plt.close()


def fmt_cpt_ac(cpts):
    return pd.DataFrame(
        [{"Weather": w, "Occupancy": o, "P(AC=On)": cpts["AC"][(w, o)][0]}
         for w in STATES["Weather"] for o in STATES["Occupancy"]]).set_index(["Weather", "Occupancy"])


SIZES = [500, 5000, 20000]


def banner(title):
    print("\n" + "=" * 72 + f"\n{title}\n" + "=" * 72)


def hand_q1():
    """Q1 by hand, marginalising Occupancy; returns (value, list of text lines)."""
    pW = dict(zip(STATES["Weather"], EXPERT["Weather"][()]))
    pD = dict(zip(STATES["DayType"], EXPERT["DayType"][()]))
    pO_high = sum(pD[d] * EXPERT["Occupancy"][(d,)][0] for d in pD)
    pO = {"High": pO_high, "Low": 1 - pO_high}
    lines = [f"P(O=High) = {pD['Weekday']}*{EXPERT['Occupancy'][('Weekday',)][0]} + "
             f"{pD['Weekend']}*{EXPERT['Occupancy'][('Weekend',)][0]} = {pO['High']:.4f};  P(O=Low) = {pO['Low']:.4f}"]
    total = 0.0
    for o in ("High", "Low"):
        pOn = sum(pW[w] * EXPERT["AC"][(w, o)][0] for w in pW)
        pH = EXPERT["Load"][(o,)][0]
        eOn = pH * EXPERT["Energy"][("On", "Heavy")][0] + (1 - pH) * EXPERT["Energy"][("On", "Light")][0]
        eOff = pH * EXPERT["Energy"][("Off", "Heavy")][0] + (1 - pH) * EXPERT["Energy"][("Off", "Light")][0]
        inner = pOn * eOn + (1 - pOn) * eOff
        total += pO[o] * inner
        lines.append(f"O={o}: P(AC=On|O)={pOn:.4f}, P(Heavy|O)={pH:.2f}, P(E=High|AC=On,O)={eOn:.4f}, "
                     f"P(E=High|AC=Off,O)={eOff:.4f}  ->  sum over AC = {inner:.5f}")
    lines.append(f"P(E=High) = {pO['High']:.4f}*{sum_inner(lines, 0):.5f} + {pO['Low']:.4f}*{sum_inner(lines, 1):.5f} = {total:.6f}")
    return total, lines


def sum_inner(lines, i):
    return float(lines[1 + i].rsplit("= ", 1)[1])


def part_a(R):
    banner("PART A: Expert Bayesian Network")
    ok = check_cpts(EXPERT, "expert")
    draw_network()
    print("Network figure saved to outputs/network.png  (open it and screenshot it)")
    expert = BN(EXPERT)
    eq = run_queries(expert)
    print()
    for q, (desc, _, _) in QUERIES.items():
        print(f"  {q}: {desc:34s} = {eq[q]:.6f}")
    print(f"\nExplaining away: Q6 = {eq['Q6']:.4f} -> Q7 = {eq['Q7']:.4f} (change {eq['Q7'] - eq['Q6']:+.4f})")
    val, lines = hand_q1()
    print("\nHand calculation of Q1:")
    for l in lines:
        print("  " + l)
    print(f"  Code value: {eq['Q1']:.6f}   Match: {np.isclose(val, eq['Q1'])}")
    R.update(eq=eq, hand=lines, hand_val=val, cpt_ok=ok)


def part_b(R):
    banner("PART B: Conditional independence (d-separation + numerical check)")
    expert = BN(EXPERT)
    H = {"Weather": "Hot"}
    checks = [
        ("1. Weather _||_ DayType", {}, {"DayType": "Weekend"}, True,
         "Only path W->AC<-O<-D is blocked at the collider AC (AC and its descendant E unobserved)."),
        ("2. Weather _||_ DayType | Energy", {"Energy": "High"}, {"DayType": "Weekend"}, False,
         "Observing E (descendant of collider AC) opens the path W->AC<-O<-D."),
        ("3. Weather _||_ Load | Occupancy", {"Occupancy": "High"}, {"Load": "Heavy"}, True,
         "Path W->AC<-O->L is blocked: AC is an unobserved collider (and O is observed on the fork)."),
    ]
    R["indep"] = []
    for name, e1, extra, holds, why in checks:
        a = expert.prob(H, e1)
        b = expert.prob(H, {**e1, **extra})
        dep = not np.isclose(a, b)
        print(f"\n{name}\n  d-separation: {'holds' if holds else 'does NOT hold'} - {why}")
        print(f"  P(W=Hot | {e1 or 'nothing'}) = {a:.6f}")
        print(f"  P(W=Hot | {{**e1, **extra}}) = {b:.6f}".replace("{**e1, **extra}", str({**e1, **extra})))
        print(f"  |diff| = {abs(a - b):.2e} -> numerically {'DEPENDENT' if dep else 'independent'}")
        R["indep"].append((name, holds, why, e1, {**e1, **extra}, a, b))


def part_c(R):
    banner(f"PART C: Synthetic data by ancestral sampling (seed = {SEED})")
    R["data"] = {}
    for n in SIZES:
        df = ancestral_sample(EXPERT, n, SEED)
        R["data"][n] = df
        df.to_csv(os.path.join(OUT, f"data_{n}.csv"), index=False)
        freq = df["Weather"].value_counts(normalize=True).reindex(STATES["Weather"])
        ct = pd.crosstab(df["Weather"], df["Occupancy"]).reindex(STATES["Weather"])[STATES["Occupancy"]]
        print(f"\n--- N = {n} ---\nWeather frequencies:  " + ", ".join(f"{k}={v:.4f}" for k, v in freq.items()))
        print("(Weather, Occupancy) counts:\n" + ct.to_string())
        R.setdefault("freq", {})[n], R.setdefault("ct", {})[n] = freq, ct


def part_de(R):
    if "eq" not in R:
        R["eq"] = run_queries(BN(EXPERT))
    if "data" not in R:
        R["data"] = {n: ancestral_sample(EXPERT, n, SEED) for n in SIZES}
    eq = R["eq"]
    banner("PARTS D & E: Learning (MLE, BDeu ESS=10) and comparison with the expert model")
    mean_err = {"MLE": [], "Bayesian": []}
    R["tables"], R["actab"], R["n500"] = {}, {}, {}
    for n in SIZES:
        df = R["data"][n]
        mle_c, bde_c = learn(df, "MLE"), learn(df, "BDeu", 10)
        check_cpts(mle_c, f"MLE n={n}"); check_cpts(bde_c, f"BDeu n={n}")
        t = fmt_cpt_ac(EXPERT).rename(columns={"P(AC=On)": "Expert"})
        t["MLE"], t["BDeu"] = fmt_cpt_ac(mle_c)["P(AC=On)"], fmt_cpt_ac(bde_c)["P(AC=On)"]
        print(f"\n--- N = {n}: learned vs expert CPT  P(AC=On | Weather, Occupancy) ---\n{t.round(4).to_string()}")
        qm, qb = run_queries(BN(mle_c)), run_queries(BN(bde_c))
        res = pd.DataFrame([{"Query": q, "Expert": eq[q], "MLE": qm[q], "Bayesian": qb[q],
                             "|Diff| MLE": abs(eq[q] - qm[q]), "|Diff| Bayesian": abs(eq[q] - qb[q])}
                            for q in QUERIES]).set_index("Query")
        print(f"\nComparison table, N = {n}\n{res.round(4).to_string()}")
        res.round(6).to_csv(os.path.join(OUT, f"comparison_{n}.csv"))
        R["tables"][n], R["actab"][n] = res, t
        mean_err["MLE"].append(res["|Diff| MLE"].mean())
        mean_err["Bayesian"].append(res["|Diff| Bayesian"].mean())
        if n == 500:
            cc = df[(df.Weather == "Cold") & (df.Occupancy == "High")]
            R["n500"] = dict(worst_mle=res["|Diff| MLE"].idxmax(), worst_bde=res["|Diff| Bayesian"].idxmax(),
                             n_ev=len(cc), n_on=int((cc.AC == "On").sum()), n_hi=int((cc.Energy == "High").sum()))
            r = R["n500"]
            print(f"\nLargest error at N=500: MLE -> {r['worst_mle']}, Bayesian -> {r['worst_bde']}")
            print(f"  Evidence for Q4 (Cold & High occupancy): {r['n_ev']} of 500 rows "
                  f"(AC=On in {r['n_on']}, Energy=High in {r['n_hi']})")
    me = pd.DataFrame(mean_err, index=SIZES)
    me.index.name = "N"
    print("\nMean |difference| over Q1-Q7:\n" + me.round(5).to_string())
    plt.figure(figsize=(6, 4))
    plt.plot(SIZES, mean_err["MLE"], "o-", label="MLE")
    plt.plot(SIZES, mean_err["Bayesian"], "s-", label="Bayesian (BDeu, ESS=10)")
    plt.xscale("log"); plt.xlabel("Dataset size"); plt.ylabel("Mean |difference| (Q1-Q7)")
    plt.title("Estimation error vs dataset size"); plt.grid(alpha=.3); plt.legend()
    plt.savefig(os.path.join(OUT, "error_vs_size.png"), dpi=150, bbox_inches="tight")
    plt.close()
    print("Plot saved to outputs/error_vs_size.png  (open it and screenshot it)")
    R["mean_err"] = me


def main():
    arg = (sys.argv[1] if len(sys.argv) > 1 else "all").upper()
    if arg not in ("A", "B", "C", "DE", "ALL"):
        sys.exit("usage: python problem1_bayesnet.py [A | B | C | DE | all]")
    pd.set_option("display.width", 200)
    R = {}
    if arg in ("A", "ALL"): part_a(R)
    if arg in ("B", "ALL"): part_b(R)
    if arg in ("C", "ALL"): part_c(R)
    if arg in ("DE", "ALL"): part_de(R)


if __name__ == "__main__":
    main()
