import sys
import re

file_path = r'c:\FlutterApps\kofund\lib\features\events\screens\tabs\event_participants_tab.dart'
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
except FileNotFoundError:
    print(f"Error: Could not open {file_path}")
    sys.exit(1)

start_marker = r"""Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {"""

end_marker = r"""                // Menu
                PopupMenuButton<String>("""

replacement = r"""Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {
  final userName = participant.userName.isNotEmpty ? participant.userName : 'Unknown User';
  final contributionPaid = participant.contributionPaid ?? 0;
  final suggestedContribution = widget.event.suggestedContribution ?? 0;
  final hasPaidFull = suggestedContribution > 0 && contributionPaid >= suggestedContribution;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Column(
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _navigateToMemberProfile(participant, context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary(context),
                        AppColors.primary(context).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 14),
                
                // Name and subtle status indication
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (suggestedContribution > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasPaidFull 
                                    ? AppColors.success(context)
                                    : AppColors.warning(context),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasPaidFull ? 'Paid in Full' : 'Pending',
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Big Contributed Amount
                if (suggestedContribution > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '₹${contributionPaid.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: hasPaidFull ? AppColors.success(context) : AppColors.textPrimary(context),
                        ),
                      ),
                      Text(
                        '/ ₹${suggestedContribution.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  
                const SizedBox(width: 8),

                // Menu
                PopupMenuButton<String>("""

# Handle the end of the widget replacing ending structure
tail_marker = r"""                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
}"""

tail_replacement = r"""                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      Divider(height: 1, thickness: 1, color: AppColors.border(context)),
    ],
  );
}"""

# Step 1: Split
split1 = content.split("Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {")
if len(split1) < 2:
    print('Failed start')
    sys.exit(1)

before = split1[0]
after_start = "Widget _buildParticipantCard(ParticipantModel participant, BuildContext context) {" + split1[1]

# In the current file, the end_marker might be different. Let's use `// Menu` which I added.
split2 = after_start.split(end_marker)
if len(split2) < 2:
    # Try another end marker
    alt_end_marker = r"""                // Column 4: Three-dot menu
                PopupMenuButton<String>("""
    split2 = after_start.split(alt_end_marker)
    if len(split2) < 2:
        print('Failed end')
        sys.exit(1)

content_with_top_replaced = before + replacement + split2[1]

# Step 2: Replace tail
split3 = content_with_top_replaced.split(tail_marker)
if len(split3) < 2:
    print('Failed tail split')
    # Save the intermediate content to debug
    with open(r'c:\FlutterApps\kofund\debug.dart', 'w', encoding='utf-8') as f:
        f.write(content_with_top_replaced)
    sys.exit(1)

final_content = split3[0] + tail_replacement + split3[1]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(final_content)
    
print("Success")
