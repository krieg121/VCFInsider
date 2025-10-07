#!/usr/bin/env bash
set -euo pipefail

# Remove duplicate/misconfigured "AI & Automation" page if it exists.
# Your homepage already routes that card to the Automation category page.
if [ -f "_pages/categories-ai-automation.md" ]; then
  echo "Removing _pages/categories-ai-automation.md (duplicate of Automation)..."
  git rm -f _pages/categories-ai-automation.md || rm -f _pages/categories-ai-automation.md
fi

# Canonical category pages with standardized front matter
cat > _pages/categories-cloud-foundation.md <<'EOF'
---
layout: category
title: Cloud Foundation
permalink: /categories/cloud-foundation/
category: Cloud Foundation
description: Posts related to VMware Cloud Foundation.
icon: "🌩️"
accent: "#002856"
---
EOF

cat > _pages/categories-networking.md <<'EOF'
---
layout: category
title: Networking
permalink: /categories/networking/
category: Networking
description: NSX and networking-related content.
icon: "🌐"
accent: "#0077C8"
---
EOF

cat > _pages/categories-security.md <<'EOF'
---
layout: category
title: Security
permalink: /categories/security/
category: Security
description: Hardening, best practices, and security guidance.
icon: "🔒"
accent: "#2BB0B1"
---
EOF

cat > _pages/categories-automation.md <<'EOF'
---
layout: category
title: Automation
permalink: /categories/automation/
category: Automation
description: PowerCLI, vRO/vRA, pipelines, and integrations.
icon: "⚙️"
accent: "#22A699"
---
EOF

cat > _pages/categories-finops.md <<'EOF'
---
layout: category
title: FinOps
permalink: /categories/finops/
category: FinOps
description: Cost visibility, rightsizing, and chargeback/showback.
icon: "📊"
accent: "#845EF7"
---
EOF

echo "Staging and committing standardized category pages..."
git add _pages/categories-*.md || true
git commit -m "Standardize category front matter: icons + hex accents; remove duplicate AI & Automation page" || true

echo "Done. Re-run the audit next:"
echo "  ./audit_vcfinsider.sh"
