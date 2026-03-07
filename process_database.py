import sys, os, json, argparse

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
INSTANCES_DIR = os.path.join(SCRIPT_DIR, "instances")

# Numerical constants matching the GOC library.
INFTY = 10e50
EPS = 10e-6

def epsilon_equal(a, b):
    return abs(a - b) < EPS

def epsilon_bigger(a, b):
    return a - EPS > b

def epsilon_smaller(a, b):
    return a + EPS < b


# Returns: the travel time for arc (i, j) departing at t0.
# Returns INFTY if infeasible.
def travel_time(instance, i, j, t0):
    c = instance["clusters"][i][j]
    T = instance["speed_zones"]
    speed = instance["cluster_speeds"][c]
    d = instance["distances"][i][j]
    t = t0
    for k in range(len(T)):
        if epsilon_equal(d, 0.0):
            break
        if epsilon_smaller(T[k][1], t0):
            continue
        remaining_time_in_k = T[k][1] - max(T[k][0], t0)
        time_to_complete_d_in_k = d / speed[k]
        time_in_k = min(remaining_time_in_k, time_to_complete_d_in_k)
        t += time_in_k
        d -= time_in_k * speed[k]
    if epsilon_bigger(d, 0.0):
        return INFTY
    return t - t0


# Returns: the departure time for arc (i, j) if arriving at tf.
# Returns INFTY if infeasible.
def departing_time(instance, i, j, tf):
    c = instance["clusters"][i][j]
    T = instance["speed_zones"]
    speed = instance["cluster_speeds"][c]
    d = instance["distances"][i][j]
    t = tf
    for k in range(len(T) - 1, -1, -1):
        if epsilon_equal(d, 0.0):
            break
        if epsilon_bigger(T[k][0], tf):
            continue
        remaining_time_in_k = min(T[k][1], tf) - T[k][0]
        time_to_complete_d_in_k = d / speed[k]
        time_in_k = min(remaining_time_in_k, time_to_complete_d_in_k)
        t -= time_in_k
        d -= time_in_k * speed[k]
    if epsilon_bigger(d, 0.0):
        return INFTY
    return t


# Returns: the travel time PWL function for arc (i, j) as a list of linear pieces.
# Each piece is [[x1, y1], [x2, y2]] representing a linear segment of the travel time function.
def compute_travel_time_function(instance, i, j):
    speed_zones = instance["speed_zones"]

    # Speed zone boundary breakpoints.
    speed_breakpoints = [zone[0] for zone in speed_zones]
    speed_breakpoints.append(speed_zones[-1][1])

    # B1: speed breakpoints from which departure is feasible.
    B1 = [t for t in speed_breakpoints if travel_time(instance, i, j, t) != INFTY]

    # B2: departure times that result in arriving exactly at a speed zone boundary.
    B2 = []
    for t in speed_breakpoints:
        dt = departing_time(instance, i, j, t)
        if dt != INFTY:
            B2.append(dt)

    # Merge, sort, and deduplicate breakpoints (using epsilon equality).
    all_breakpoints = sorted(set(B1 + B2))
    B = []
    for t in all_breakpoints:
        if not B or not epsilon_equal(B[-1], t):
            B.append(t)

    if len(B) < 2:
        return []

    # Compute travel time values at each breakpoint.
    T = [travel_time(instance, i, j, t) for t in B]

    # Build list of linear pieces [[x1, y1], [x2, y2]].
    pieces = []
    for k in range(len(B) - 1):
        pieces.append([[B[k], T[k]], [B[k + 1], T[k + 1]]])

    return pieces


# Processes an instance by computing the travel_times field.
def process_instance(instance):
    n = instance["digraph"]["vertex_count"]
    arcs = instance["digraph"]["arcs"]

    # Initialize travel_times as n x n matrix of empty lists.
    travel_times = [[[] for _ in range(n)] for _ in range(n)]

    # Compute travel time function for each arc in the digraph.
    for i in range(n):
        for j in range(n):
            if arcs[i][j] == 1:
                travel_times[i][j] = compute_travel_time_function(instance, i, j)

    instance["travel_times"] = travel_times
    return instance


def main():
    arg_parser = argparse.ArgumentParser(
        description="Pre-processes all instance JSON files in the database by computing travel time PWL functions."
    )
    arg_parser.add_argument(
        "--datasets", "-D", nargs="*",
        help="Only process the specified dataset(s). If not provided, all datasets are processed."
    )
    arg_parser.add_argument(
        "--instances", "-I", nargs="*",
        help="Only process the specified instance(s) by name. If not provided, all instances are processed."
    )
    arg_parser.add_argument(
        "--dry-run", action="store_true",
        help="Parse and process instances but do not save any files."
    )
    args = vars(arg_parser.parse_args())
    selected_datasets = args["datasets"]
    selected_instances = args["instances"]
    dry_run = args["dry_run"]

    if not os.path.isdir(INSTANCES_DIR):
        print(f"Error: instances directory not found at {INSTANCES_DIR}", file=sys.stderr)
        sys.exit(1)

    dataset_names = sorted(os.listdir(INSTANCES_DIR))
    if selected_datasets:
        dataset_names = [d for d in dataset_names if d in selected_datasets]

    total_processed = 0
    total_skipped = 0

    for dataset_name in dataset_names:
        dataset_dir = os.path.join(INSTANCES_DIR, dataset_name)
        index_path = os.path.join(dataset_dir, "index.json")

        if not os.path.isfile(index_path):
            continue

        with open(index_path) as f:
            index = json.load(f)

        print(f"Processing dataset: {dataset_name} ({len(index)} instances)")

        for entry in index:
            instance_name = entry["instance_name"]
            file_name = entry["file_name"]

            if selected_instances and instance_name not in selected_instances:
                total_skipped += 1
                continue

            file_path = os.path.join(dataset_dir, file_name)
            with open(file_path) as f:
                instance = json.load(f)

            print(f"  Processing {instance_name}...", end=" ", flush=True)
            process_instance(instance)

            if not dry_run:
                with open(file_path, "w") as f:
                    json.dump(instance, f)

            total_processed += 1
            print("done")

    print(f"\nFinished: {total_processed} instance(s) processed, {total_skipped} skipped.")


if __name__ == "__main__":
    main()
