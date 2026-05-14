import os

target_file = 'c:/FlutterApps/kofund/lib/features/dashboard/widgets/event_carousel_widget.dart'
new_code_file = 'c:/FlutterApps/kofund/tmp_card.dart'

with open(target_file, 'r', encoding='utf-8') as f:
    original = f.read()

with open(new_code_file, 'r', encoding='utf-8') as f:
    new_card_code = f.read()

# Replace height
original = original.replace('height: 320,', 'height: 280,')

# Cut off before the card
marker = '// ── Individual card'
idx = original.find(marker)
if idx != -1:
    final_code = original[:idx] + new_card_code
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(final_code)
    print("Successfully updated event_carousel_widget.dart")
else:
    print("Error: marker not found")
