---
name: list_workers
version: "1.0"
notebook: null
category: utility
tags: [debug, introspection, development]
parameters:
  subdir:
    type: str
    default: "workers"
    description: "Subdirectory to list notebooks from"
    examples: ["workers", "raglearning"]
---

# List Workers

List all available worker notebooks for debugging and introspection.

## Description

This development utility lists the underlying notebook files that power
the RAG tools. Useful for debugging, development, and understanding
the system architecture.

## Purpose

- **Discovery**: See what notebooks are available
- **Debugging**: Understand the system structure
- **Development**: Find notebooks to work with
- **Introspection**: Explore different subdirectories

## Returns

Dictionary containing:
- **subdir**: The subdirectory that was searched
- **notebooks**: List of notebook paths (e.g., ["workers/notebook1.ipynb"])
- **count**: Number of notebooks found
- **path**: Full path to the searched directory

## Available Subdirectories

- `workers`: Core RAG implementation notebooks
- `raglearning`: Your experimental and learning notebooks

## Example Usage

### List workers in default directory
```python
result = list_workers()
print(f"Workers: {result['notebooks']}")
```

### List notebooks in raglearning directory
```python
result = list_workers("raglearning")
print(f"Learning notebooks: {result['notebooks']}")
```

## Note

This is a development/debugging tool. In production scenarios,
clients should use the specific RAG tools rather than working
with raw notebook files.
