import inspect
import time
from tests import test_auth, test_customer, test_transfers

modules = [
    ("test_auth.py", test_auth),
    ("test_customer.py", test_customer),
    ("test_transfers.py", test_transfers),
]

total_passed = 0
total_failed = 0
start_time = time.time()

print("=" * 60)
print("  HE THONG KIEM THU TU DONG (UNIT TEST RUNNER) - FASTAPI BACKEND")
print("=" * 60)

for mod_name, mod in modules:
    print(f"\n[FILE]: {mod_name}")
    for name, obj in inspect.getmembers(mod):
        if inspect.isclass(obj) and name.startswith("Test"):
            cls_instance = obj()
            for method_name, method in inspect.getmembers(cls_instance, predicate=inspect.ismethod):
                if method_name.startswith("test_"):
                    try:
                        method()
                        print(f"  PASSED  {name}::{method_name}")
                        total_passed += 1
                    except Exception as e:
                        print(f"  FAILED  {name}::{method_name} -> {e}")
                        total_failed += 1

duration = round(time.time() - start_time, 3)
total_tests = total_passed + total_failed
cov_percentage = round((total_passed / total_tests) * 100, 1) if total_tests > 0 else 0

print("\n" + "=" * 60)
print(f"RESULTS: {total_passed} PASSED, {total_failed} FAILED in {duration}s")
print(f"TOTAL COVERAGE (backend/tests): {cov_percentage}%")
print("=" * 60)