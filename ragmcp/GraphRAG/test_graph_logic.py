"""
Test the fixed GraphRAG logic without requiring Ollama.
Tests: detect_anchor_entity, search_graph (CamelCase + fuzzy node lookup).

Run:
    python test_graph_logic.py
    # or via papermill (full notebook):
    # papermill "Historical_GraphRAG_Demo - Copy.ipynb" output.ipynb --no-inject-paths 2>&1
"""
import re
import networkx as nx

# ── replicate the graph globals the notebook uses ──────────────────────────
G = nx.MultiDiGraph()
# Simulate garbage entity names extracted by the small Ollama model
_triples = [
    ("AlbertEinstein", "developed", "TheoryOfRelativity"),
    ("AlbertEinstein", "influenced", "QuantumMechanics"),
    ("AlbertEinstein", "collaborated_with", "NielsBohr"),
    ("ManhattanProject", "included", "AlbertEinstein"),
    ("Subject3", "born_in", "Germany"),
]
for u, rel, v in _triples:
    G.add_edge(u, v, relation=rel)

known_entities = set(G.nodes())
entity_usage = {n: G.degree(n) for n in G.nodes()}

# ── paste the exact functions from the notebook ───────────────────────────

import re as _re

def _camel_split(text):
    spaced = _re.sub(r"([a-z])([A-Z])", r"\1 \2", text)
    return spaced.lower()

def _node_word_score(anchor_words, node):
    node_words = set(_re.findall(r"[a-z]+", _camel_split(node)))
    if not node_words or not anchor_words:
        return 0
    return len(anchor_words & node_words) / max(len(anchor_words), len(node_words))

def search_graph(anchor: str, depth: int = 2) -> nx.Graph:
    nonlocal_anchor = anchor
    if anchor not in G:
        anchor_words = set(w for w in _re.findall(r"[a-z]+", _camel_split(anchor)) if len(w) > 2)
        best_node, best_score = None, 0.0
        for node in G.nodes():
            score = _node_word_score(anchor_words, node)
            if score > best_score:
                best_score, best_node = score, node
        if best_node and best_score >= 0.25:
            print(f"ℹ️  '{anchor}' not in graph — using closest node: '{best_node}' (score {best_score:.2f})")
            nonlocal_anchor = best_node
        else:
            print(f"⚠️  Entity '{anchor}' not found in graph. Known nodes: {list(G.nodes())[:10]}")
            return nx.Graph()
    undirected_G = G.to_undirected()
    visited_nodes = {nonlocal_anchor}
    current_level = {nonlocal_anchor}
    for _ in range(depth):
        next_level = set()
        for node in current_level:
            for neighbor in undirected_G.neighbors(node):
                if neighbor not in visited_nodes:
                    next_level.add(neighbor)
        visited_nodes.update(next_level)
        current_level = next_level
    return G.subgraph(visited_nodes).copy()

import re as _re2

def detect_anchor_entity(question: str) -> str:
    question_lower = question.lower()
    question_words = set(w for w in _re2.findall(r"[a-z]+", question_lower) if len(w) > 2)
    sorted_entities = sorted(known_entities, key=lambda e: -entity_usage.get(e, 0))
    best_entity, best_score = None, 0.0
    for entity in sorted_entities:
        normalized = _re2.sub(r"([a-z])([A-Z])", r"\1 \2", entity).lower()
        entity_words = [w for w in _re2.findall(r"[a-z]+", normalized) if len(w) > 3]
        if not entity_words:
            continue
        score = sum(1 for w in entity_words if w in question_words) / len(entity_words)
        if score > best_score:
            best_score, best_entity = score, entity
    if best_entity and best_score > 0:
        return best_entity
    return sorted_entities[0] if sorted_entities else ""

# ── tests ─────────────────────────────────────────────────────────────────

def test_detect_anchor_camelcase():
    """'AlbertEinstein' node should be found for an Einstein question."""
    result = detect_anchor_entity("How did Albert Einstein contribute to the atomic bomb?")
    assert result == "AlbertEinstein", f"Expected AlbertEinstein, got {result}"
    print(f"✅ test_detect_anchor_camelcase → {result}")

def test_detect_anchor_partial():
    """CamelCase split 'TheoryOfRelativity' should match 'relativity' question."""
    result = detect_anchor_entity("What is the theory of relativity?")
    assert result == "TheoryOfRelativity", f"Expected TheoryOfRelativity, got {result}"
    print(f"✅ test_detect_anchor_partial → {result}")

def test_search_graph_exact():
    """search_graph with an exact node name returns a non-empty subgraph."""
    sg = search_graph("AlbertEinstein", depth=2)
    assert len(sg.nodes()) > 0, "Expected non-empty subgraph"
    print(f"✅ test_search_graph_exact → {len(sg.nodes())} nodes")

def test_search_graph_fuzzy():
    """search_graph with 'Albert Einstein' (spaced, not in graph) fuzzy-matches AlbertEinstein."""
    sg = search_graph("Albert Einstein", depth=1)
    assert len(sg.nodes()) > 0, "Expected fuzzy match to return nodes"
    print(f"✅ test_search_graph_fuzzy → {len(sg.nodes())} nodes (fuzzy match)")

def test_search_graph_missing_entity_no_crash():
    """search_graph on a completely unknown entity returns empty graph, no ValueError."""
    sg = search_graph("Napoleon Bonaparte", depth=1)
    assert isinstance(sg, nx.Graph), "Should return a Graph object, not raise"
    print(f"✅ test_search_graph_missing_entity_no_crash → empty graph, no crash")

if __name__ == "__main__":
    tests = [
        test_detect_anchor_camelcase,
        test_detect_anchor_partial,
        test_search_graph_exact,
        test_search_graph_fuzzy,
        test_search_graph_missing_entity_no_crash,
    ]
    passed = 0
    for t in tests:
        try:
            t()
            passed += 1
        except AssertionError as e:
            print(f"❌ {t.__name__}: {e}")
    print(f"\n{'✅ All' if passed == len(tests) else f'{passed}/{len(tests)}'} tests passed.")
