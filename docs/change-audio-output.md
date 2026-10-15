```bash
pactl info | grep "Server Name"
pactl list short sink-inputs   # Note the INPUT_ID column
pactl move-sink-input <input_id> <sink_name_or_index>
```
