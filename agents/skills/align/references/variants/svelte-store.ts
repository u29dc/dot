export function createStore<T>(initial: T) {
	let value = $state<T>(initial);
	return {
		get value() {
			return value;
		},
		set(next: T) {
			value = next;
		},
	};
}
