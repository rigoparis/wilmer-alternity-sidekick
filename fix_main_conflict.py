import re

with open('scripts/main.gd', 'r') as f:
    content = f.read()

# Apply the merge from main manually while preserving our theme changes.
# I actually checked out the original branch's main.gd.
# Now I need to see what `main.gd` in `origin/main` has that I am missing.
