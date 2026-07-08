import Flutter
import HealthKit

class SwimHealthChannel {
    private let healthStore = HKHealthStore()
    
    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.jro.swimtracker/health",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getSwimmingWorkouts":
                let days = (call.arguments as? Int) ?? 90
                self?.getSwimmingWorkouts(days: days, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func getSwimmingWorkouts(days: Int, result: @escaping FlutterResult) {
        // Vérifie que HealthKit est disponible
        guard HKHealthStore.isHealthDataAvailable() else {
            result(FlutterError(code: "UNAVAILABLE",
                              message: "HealthKit not available",
                              details: nil))
            return
        }
        
        // Types à lire
        let workoutType = HKObjectType.workoutType()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!
        
        let typesToRead: Set<HKObjectType> = [workoutType, heartRateType, caloriesType, distanceType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            guard success else {
                result(FlutterError(code: "PERMISSION",
                                  message: "HealthKit permission denied",
                                  details: nil))
                return
            }
            
            // Filtre natation sur X jours
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
            let swimmingPredicate = HKQuery.predicateForWorkouts(with: .swimming)
            let openWaterPredicate = HKQuery.predicateForWorkouts(with: .swimming)
            
            let swimmingTypes = NSCompoundPredicate(orPredicateWithSubpredicates: [
                swimmingPredicate, openWaterPredicate
            ])
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [
                datePredicate, swimmingTypes
            ])
            
            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate,
                ascending: false
            )
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: compound,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                guard let workouts = samples as? [HKWorkout], error == nil else {
                    result([])
                    return
                }
                
                // Pour chaque workout, récupère FC, calories, distance
                let group = DispatchGroup()
                var sessionList: [[String: Any]] = []
                
                for workout in workouts {
                    group.enter()
                    self?.fetchWorkoutDetails(workout: workout) { details in
                        sessionList.append(details)
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    result(sessionList)
                }
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchWorkoutDetails(workout: HKWorkout,
                                     completion: @escaping ([String: Any]) -> Void) {
        let wStart = workout.startDate
        let wEnd = workout.endDate
        let predicate = HKQuery.predicateForSamples(withStart: wStart, end: wEnd)
        
        var session: [String: Any] = [
            "startedAt": wStart.timeIntervalSince1970 * 1000,
            "endedAt": wEnd.timeIntervalSince1970 * 1000,
            "durationSeconds": Int(workout.duration),
            "distanceMeters": workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            "calories": workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
            "workoutType": workout.workoutActivityType == .swimming
                ? "openWater" : "pool",
        ]
        
        // Récupère FC
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let hrQuery = HKStatisticsQuery(
            quantityType: hrType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage, .discreteMax]
        ) { _, stats, _ in
            if let avg = stats?.averageQuantity() {
                session["heartRateAvg"] = avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
            if let max = stats?.maximumQuantity() {
                session["heartRateMax"] = max.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
            completion(session)
        }
        
        healthStore.execute(hrQuery)
    }
}