#!/usr/bin/env python3
from pathlib import Path

path = Path('lib/services/trade_machine_engine.dart')
text = path.read_text(encoding='utf-8')
text = text.replace(
    "if (context.aboveFirstApron || postTradeSalary > context.firstApron) {\n      return outgoingSalary + 250000;\n    }",
    "if (context.aboveFirstApron || postTradeSalary > context.firstApron) {\n      // First-apron teams may not take back more salary than they send out.\n      // Special-case exception mechanics belong in an explicit exception record,\n      // not in a permissive generic matching cushion.\n      return outgoingSalary;\n    }",
)
path.write_text(text, encoding='utf-8')
print('hardened first-apron matching')
