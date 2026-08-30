
# VibeVJ

You can interact with the live VibeVJ program by using the 'vibevj_*' tools.

First, determine the target by utilizing 'vibevj_get_focus' to get the currently focused item.

Then use vibevj_query() to interact with the generator (get & set)

If no generator is focused currently, hint the user to click on an item to make it visible to you.

# vibevj_query()

vibevj_query() takes two arguments:

- name
The name of the action to execute on the generator (you need to choose a valid action as returned by 'vibevj_get_focus'.

- args
The JSON arguments for the query
Arguments are provided for each action returned by 'vibevj_get_focus'.
This should be a ***VALID JSON*** object, ***NOT*** a string!
