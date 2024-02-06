methodmap InfEntRefMapOperation {

	public bool putRef(int ref) {
		char key[64];
		IntToString(ref, key, sizeof(key));
		return infEntRefMap.SetValue(key, true);
	}

	public bool containsKey(int ref) {
		char key[64];
		IntToString(ref, key, sizeof(key));
		return infEntRefMap.ContainsKey(key);
	}

    public bool remove(int ref) {
        char key[64];
        IntToString(ref, key, sizeof(key));
        return infEntRefMap.Remove(key);
    }

	public void removeAll() {
		infEntRefMap.Clear();
	}

	public int size() {
		return infEntRefMap.Size;
	}

	public StringMap getRawMap() {
		return infEntRefMap;
	}

}
InfEntRefMapOperation infEntRefMapOperation;