**Settings Block**
```octave
simulation_time = 480;
lambda          = 0.30;
mu              = 0.30;
num_doctors     = 3;
queue_mode      = 'priority';
```
These are just your control knobs. `lambda = 0.30` means 0.30 patients arrive per minute on average (= 18/hour). Change these to switch scenarios — nothing else needs touching.

---

**Doctor Initialisation**
```octave
for d = 1:num_doctors
  doctor(d).status    = 0;
  doctor(d).busy_time = 0;
end
```
Creates a record per doctor. Each starts idle with zero minutes worked. Think of it as a staff roster.
> `doctor(1) = {status=0, busy_time=0}`
> `doctor(2) = {status=0, busy_time=0}`

---

**Future Event List**
```octave
first_arrival.time      = generate_interarrival_time(lambda);
first_arrival.type      = 1;
first_arrival.patientID = 0;
first_arrival.doctorID  = 0;
future_event(1) = first_arrival;
```
The FEL is a to-do list of things that haven't happened yet. Only two types of things can happen — a patient arriving (type 1) or a doctor finishing (type 2). You seed it with one arrival to get the chain started. Everything after that gets scheduled dynamically.
> `future_event(1) = {time=2.3, type=1, patientID=0, doctorID=0}`

---

**Finding the Earliest Event**
```octave
event_times       = [future_event.time];
[min_time, idx]   = min(event_times);
current_event     = future_event(idx);
future_event(idx) = [];
clock = current_event.time;
```
Pulls all event times into a flat array, finds the earliest, grabs that event and removes it from the list. The clock jumps forward to that event's time — the simulation doesn't run in real time, it skips straight from event to event.
> `event_times = [2.3, 7.1, 5.6]`
> `idx = 1, clock = 2.3`
> `current_event = {time=2.3, type=1, patientID=0, doctorID=0}`

---

**Queue Area Update**
```octave
dt         = effective_time - last_event_time;
queue_area = queue_area + (length(queue) * dt);
```
Before moving the clock, record how long the queue stayed at its current length. For example if 2 people were waiting for 4 minutes, that contributes 8 to `queue_area`. At the end you divide by simulation time to get the average. This is called time-weighted averaging.
> `queue = [3, 7]` → length = 2, dt = 4.0 → queue_area += 8.0

---

**Arrival — Register Patient**
```octave
patients(pid).arrival_time  = clock;
patients(pid).priority      = assign_priority();
patients(pid).service_start = -1;
patients(pid).service_end   = -1;
```
A new patient shows up. They get an ID, arrival time stamped, and a priority level drawn randomly. `service_start = -1` means not yet seen — gets updated when a doctor takes them.
> `patients(1) = {arrival_time=2.3, priority=2, service_start=-1, service_end=-1}`

---

**Arrival — Schedule Next Arrival**
```octave
next_arrival = clock + generate_interarrival_time(lambda);
future_event(end + 1) = e;
```
Immediately schedules the next patient. This is how the chain keeps going — every arrival triggers another arrival. The next patient has no ID yet so `patientID=0`.
> `future_event = [{time=2.3,...}, {time=5.6, type=1, patientID=0, doctorID=0}]`

---

**Arrival — Find Free Doctor**
```octave
free_doctor = 0;
for d = 1:num_doctors
  if doctor(d).status == 0
    free_doctor = d;
    break;
  end
end
```
Scans doctors one by one for anyone idle. Takes the first one found and stops. If nobody is free, `free_doctor` stays 0.
> `doctor(1).status = 1` (busy)
> `doctor(2).status = 0` → `free_doctor = 2`

---

**Arrival — Serve or Queue**
```octave
if free_doctor ~= 0
  % serve immediately, schedule departure
else
  queue(end + 1) = pid;
end
```
Doctor free — serve now and push a departure event into the FEL. All doctors busy — patient ID goes into the queue. The queue only stores IDs, not full records.

Doctor free:
> `future_event(end+1) = {time=9.1, type=2, patientID=1, doctorID=2}`

All busy:
> `queue = [1]`

---

**Departure — Finish Patient**
```octave
patients(pid).service_end = clock;
served_patients           = served_patients + 1;
```
Doctor finishes. Patient's end time gets stamped, served counter goes up.
> `patients(1).service_end = 9.1, served_patients = 1`

---

**Departure — Priority Scan**
```octave
for k = 2:length(queue)
  candidate = queue(k);
  if patients(candidate).priority < patients(best_patient).priority
    best_patient = candidate;
    best_index   = k;
  elseif ...same priority, pick earliest arrival...
  end
end
queue(best_index) = [];
```
Someone is waiting so the doctor picks their next patient. In priority mode it scans the whole queue for the lowest priority number (1 = Critical). If two share the same level, pick whoever arrived first. `best_index` tracks where in the queue that patient sits so they can be removed cleanly.
> `queue = [3, 5, 7]`
> `patients(3).priority=2, patients(5).priority=1, patients(7).priority=3`
> `best_patient=5, best_index=2 → queue = [3, 7]`

---

**Metrics**
```octave
wait = patients(i).service_start - patients(i).arrival_time;
```
Wait time = when doctor took them minus when they walked in.
> `patients(3) = {arrival_time=6.0, service_start=9.1}` → wait = 3.1 mins

```octave
avg_queue_length = queue_area / simulation_time;
```
Total accumulated queue area divided by how long the simulation ran.
> `queue_area=42.3, simulation_time=480` → avg = 0.088 patients

```octave
overall_util = (total_busy_time / (num_doctors * simulation_time)) * 100;
```
Fraction of total available doctor-minutes actually spent treating. 3 doctors over 480 minutes = 1440 possible doctor-minutes total.
> `total_busy_time=610, num_doctors=2` → util = 63.5%