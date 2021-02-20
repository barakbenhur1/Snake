//
//  ViewController.swift
//  Snake
//
//  Created by Interactech on 12/02/2021.
//

import UIKit

// move method enum
enum MoveMethod: String {
   case tap, swip
}

enum FoodType: String {
    case regular, slow, doNoting
}

class BoardContainerViewController: UIViewController {
    
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var leftView: UIView!
    @IBOutlet weak var rightView: UIView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var moveMethodSwitch: UISwitch!
    @IBOutlet weak var highScore: UILabel!
    
    private var isFromBackground = false
    
    private var board: Board!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let isOn: Bool = UserDefaults.standard.value(forKey: "MoveMethod") as? Bool ?? false
        self.moveMethodSwitch.isOn = isOn
        
        let moveMethod: MoveMethod = isOn ? .swip : .tap
        
        prepareGameFrame()
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal          // Set defaults to the formatter that are common for showing decimal numbers
        numberFormatter.usesGroupingSeparator = true    // Enabled separator
        numberFormatter.groupingSeparator = ","         // Set the separator to "," (e.g. 1000000 = 1,000,000)
        numberFormatter.groupingSize = 3                // Set the digits between each separator
        
        let score = UserDefaults.standard.value(forKey: "highScore") as? Int ?? 0
        
        let scoreString = numberFormatter.string(from: NSNumber(value: score))!
        
        highScore.text = "High Score: \(scoreString)"
        
        board = Board.create(to: self, numberOfRows: 8, moveMethod: moveMethod, scoreComp: { [weak self] score in
            self?.countLabel.text = "Food: \(score)"
        })
        
        board.startOverInformer = {  [weak self] in
            self?.countLabel.text = "Food: 0"
            self?.timeLabel.text = "Time: 0 seconds"
        }
        
        board.timePlayedInformer = {  [weak self] time in
            self?.timeLabel.text = "Time: \(time) seconds"
        }
    }
    
    
    @objc func stopGame() {
        self.isFromBackground = true
        board.stopGame()
    }
    
    @objc func resumeGame() {
        if isFromBackground {
            isFromBackground = false
            board.resumeGame()
        }
    }
    
    @IBAction func switchMoveMethod(_ sender: UISwitch, forEvent event: UIEvent) {
        
        UserDefaults.standard.set(sender.isOn, forKey: "MoveMethod")
        
        if sender.isOn {
            board.switchMoveMothod(to: .swip)
        }
        else {
            board.switchMoveMothod(to: .tap)
        }
    }
    
    private func prepareGameFrame() {
        titleView.layer.shadowColor = UIColor.black.cgColor
        titleView.layer.shadowOpacity = 1
        titleView.layer.shadowOffset = .zero
        titleView.layer.shadowRadius = 10
        titleView.layer.shouldRasterize = true
        titleView.layer.rasterizationScale = UIScreen.main.scale
        
        leftView.layer.shadowColor = UIColor.black.cgColor
        leftView.layer.shadowOpacity = 1
        leftView.layer.shadowOffset = .zero
        leftView.layer.shadowRadius = 10
        leftView.layer.shouldRasterize = true
        leftView.layer.rasterizationScale = UIScreen.main.scale
        
        rightView.layer.shadowColor = UIColor.black.cgColor
        rightView.layer.shadowOpacity = 1
        rightView.layer.shadowOffset = .zero
        rightView.layer.shadowRadius = 10
        rightView.layer.shouldRasterize = true
        rightView.layer.rasterizationScale = UIScreen.main.scale
        
        bottomView.layer.shadowColor = UIColor.black.cgColor
        bottomView.layer.shadowOpacity = 1
        bottomView.layer.shadowOffset = .zero
        bottomView.layer.shadowRadius = 10
        bottomView.layer.shouldRasterize = true
        bottomView.layer.rasterizationScale = UIScreen.main.scale
        
        countLabel.text = "Food: 0"
        
        NotificationCenter.default.addObserver(self, selector: #selector(stopGame), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(resumeGame), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}

class Board  {

    // board container view controller
    
    private var containerViewController: UIViewController?
    
    // board super view
    
    private lazy var superView: UIView = containerViewController!.view
    
    // inital params for grid calc
    private var numOfSqueresInRow = 9
    private lazy var squreSize: CGFloat = (superView.frame.width - CGFloat(numOfSqueresInRow * 5)) / CGFloat(numOfSqueresInRow)
    private lazy var boardnRatio: CGFloat = (superView.frame.height - 152.5) / (superView.frame.width - 40)
    private lazy var numOfSqueresInCol: Int = Int(CGFloat(numOfSqueresInRow) * boardnRatio)
    private lazy var boardFrame = CGRect(x: 20, y: 112, width: (squreSize * CGFloat(numOfSqueresInRow)), height: (squreSize) * CGFloat(numOfSqueresInCol))
    private lazy var boardBorder: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) = (top: boardFrame.origin.y, bottom: boardFrame.origin.y + boardFrame.height, left: boardFrame.origin.x, right: boardFrame.origin.x + boardFrame.width)
    
    // calc grid for snake
    private var boardView: UIView!
    
    // center index׳s
    private lazy var rowIndex = numOfSqueresInRow / 2
    private lazy var colIndex = (numOfSqueresInCol / 2) - 1

    // snake
    private var snake: Snake!
    
    private var foodSpownTimer: Timer?
    private var gameTimeTimer: Timer?
    
    private var spowndFoodDictinary = [String : (assets: (egg: UIImageView?, food: UIImageView), type: FoodType)]()
    
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(changeDirctionByTap(tapGestureRecognizer:)))
    
    private lazy var tapFire = UITapGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipFireDown = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipFireUp = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipFireLeft = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipFireRight = UISwipeGestureRecognizer(target: self, action: #selector(fire(gestureRecognizer:)))
    
    private lazy var swipDown = UISwipeGestureRecognizer(target: self, action: #selector(changeDirctionBySwip(swipGestureRecognizer:)))
    
    private lazy var swipUp = UISwipeGestureRecognizer(target: self, action: #selector(changeDirctionBySwip(swipGestureRecognizer:)))
    
    private lazy var swipRight = UISwipeGestureRecognizer(target: self, action: #selector(changeDirctionBySwip(swipGestureRecognizer:)))
    
    private lazy var swipLeft = UISwipeGestureRecognizer(target: self, action: #selector(changeDirctionBySwip(swipGestureRecognizer:)))
    
    var foodCountComp: ((Int) -> ())?
    
    var startOverInformer: (() -> ())?
    
    var timePlayedInformer: ((Int) -> ())?
    
    private var count: Int = 0
    private var time: Int = 0
    
    // MARK: buildBoard
    
    private init() {}
    
    @discardableResult
    static func create(to vc: UIViewController, numberOfRows: Int, moveMethod: MoveMethod, scoreComp: @escaping ((Int) -> ())) -> Board {
        // Build Container view for board
        
        let board = Board()
        
        board.foodCountComp = scoreComp
        
        board.numOfSqueresInRow = numberOfRows
        
        board.containerViewController = vc
        
        board.boardView = UIView(frame: board.boardFrame)
        
        // calc grid for snake
        let table = board.createTable()
        
        // add table to board
        board.boardView.addSubview(table)
        
        // init touch for navigation
        board.switchMoveMothod(to: moveMethod)
        
        board.swipUp.direction = .up
        board.swipDown.direction = .down
        board.swipLeft.direction = .left
        board.swipRight.direction = .right
        
        board.swipFireUp.direction = .up
        board.swipFireDown.direction = .down
        board.swipFireLeft.direction = .left
        board.swipFireRight.direction = .right
        
        // add boardView to viewController
        board.superView.addSubview(board.boardView)
        
        board.startGame()
        
        return board
    }
    
    func switchMoveMothod(to mothod: MoveMethod) {
        
        boardView.removeGestureRecognizer(tap)
        boardView.removeGestureRecognizer(swipUp)
        boardView.removeGestureRecognizer(swipDown)
        boardView.removeGestureRecognizer(swipLeft)
        boardView.removeGestureRecognizer(swipRight)
        boardView.removeGestureRecognizer(swipFireUp)
        boardView.removeGestureRecognizer(swipFireDown)
        boardView.removeGestureRecognizer(swipFireLeft)
        boardView.removeGestureRecognizer(swipFireRight)
        boardView.removeGestureRecognizer(tapFire)
        
        switch mothod {
        case .tap:
            boardView.addGestureRecognizer(tap)
            boardView.addGestureRecognizer(swipFireUp)
            boardView.addGestureRecognizer(swipFireDown)
            boardView.addGestureRecognizer(swipFireLeft)
            boardView.addGestureRecognizer(swipFireRight)
        case .swip:
            boardView.addGestureRecognizer(swipUp)
            boardView.addGestureRecognizer(swipDown)
            boardView.addGestureRecognizer(swipLeft)
            boardView.addGestureRecognizer(swipRight)
            boardView.addGestureRecognizer(tapFire)
        //        default:
        //            boardView.addGestureRecognizer(tap)
        }
    }
    
    private func startGame() {
        self.boardView.subviews.forEach { (subView) in
            if subView is UIImageView{
                subView.removeFromSuperview()
            }
        }
        
        count = 0
        
        spownTime = 1.6
        
        spowndFoodDictinary = [String : (assets: (egg: UIImageView, food: UIImageView), type: FoodType)]()
        
        startOverInformer?()
        
        addSnakeToBoard()
        
        var i = 0
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            i += 1
            self?.time = i
            self?.timePlayedInformer?(i)
        }
        
        gameTimeTimer = timer
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    @objc func fire(gestureRecognizer: UITapGestureRecognizer) {
        snake.fire { [self] (bullet) in
            boardView.addSubview(bullet)
        } borderHendaler: { [self] (bullet, timer) -> (Bool) in
            if bullet.frame.origin.x <= superView.frame.origin.x - 20 || bullet.frame.origin.x >=  superView.frame.origin.x + superView.frame.width - 40 || bullet.frame.origin.y <= superView.frame.origin.y - 30 || bullet.frame.origin.y >= superView.frame.origin.y + superView.frame.height - 190 {
                timer.invalidate()
                bullet.removeFromSuperview()
                return true
            }
            
            for keyValue in spowndFoodDictinary {
                if keyValue.value.assets.food.frame.contains(bullet.center) {
                    guard let egg = keyValue.value.assets.egg else {
                        keyValue.value.assets.food.removeFromSuperview()
                        spowndFoodDictinary[keyValue.key] = nil
                        timer.invalidate()
                        bullet.removeFromSuperview()
                        return true
                    }
                    
                    egg.removeFromSuperview()
                    spowndFoodDictinary[keyValue.key]?.assets.egg = nil
                    timer.invalidate()
                    bullet.removeFromSuperview()
                    return true
                }
            }
            return false
        } fireBlocked: { (bullet) in
            bullet.removeFromSuperview()
        }
    }
    
    // MARK: Change Direction Methods - Tap / Swip
    
    @objc func changeDirctionByTap(tapGestureRecognizer: UITapGestureRecognizer) {
        let loc = tapGestureRecognizer.location(in: boardView)
        
        guard let snkeMoveDiff = calcSnakeMoveDiff(loc) else { return }
        
        switch snkeMoveDiff {
        case (let x , let y) where abs(y) > abs(x):
            if let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.x != prv.image?.frame.origin.x else {
                    return
                }
            }
            
            switch y {
            case ..<0:
                snake!.direction = .down
            default:
                snake!.direction = .up
            }
        default:
            if  let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.y != prv.image?.frame.origin.y else {
                    return
                }
            }
            
            switch snkeMoveDiff.xDiff {
            case ..<0:
                snake!.direction = .right
            default:
                snake!.direction = .left
            }
        }
    }
    
    @objc func changeDirctionBySwip(swipGestureRecognizer: UISwipeGestureRecognizer) {
        switch swipGestureRecognizer.direction {
        case .up, .down:
            if let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.x != prv.image?.frame.origin.x else {
                    return
                }
            }
            
        case .left, .right:
            if let head = Snake.head, let prv = head.prv {
                guard head.image?.frame.origin.y != prv.image?.frame.origin.y else {
                    return
                }
            }
            
        default:
            return
        }
        
        switch swipGestureRecognizer.direction {
        case .up:
            snake!.direction = .up
        case .down:
            snake!.direction = .down
            
        case .left:
            snake!.direction = .left
        case .right:
            snake!.direction = .right
            
        default:
            return
        }
    }
    
    // calc snake head location diff from a given point
    private func calcSnakeMoveDiff(_ aginst: CGPoint) -> (xDiff: CGFloat, yDiff: CGFloat)? {
        let snakeHead = Snake.head!.image
        
        let snakeHeadXxis = snakeHead!.frame.origin.x
        let snakeHeadYxis = snakeHead!.frame.origin.y
        
        let yXisDiff = snakeHeadYxis - aginst.y
        let xXisDiff = snakeHeadXxis - aginst.x
        
        return (xXisDiff , yXisDiff)
    }
    
    
    // MARK: Create Grid For Board -
    
    // MARK: createStackView ( params { heightAnchorConstant: height for stack view, widthAnchorConstant:  width for stack view, axis: vertical || horizontal } )
    
    private func createStackView(heightAnchorConstant: CGFloat, widthAnchorConstant: CGFloat, axis: NSLayoutConstraint.Axis) -> UIStackView {
        let stackView = UIStackView()
        stackView.alignment = .fill
        stackView.axis = axis
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.heightAnchor.constraint(equalToConstant: heightAnchorConstant).isActive = true
        stackView.widthAnchor.constraint(equalToConstant: widthAnchorConstant).isActive = true
        
        return stackView
    }
    
    // MARK: squreView ( params { borderColor: black, bordexrWidth: 2 } )
    private func squreView() -> UIView {
        let view = UIView()
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.heightAnchor.constraint(equalToConstant: squreSize).isActive = true
        view.widthAnchor.constraint(equalToConstant: squreSize).isActive = true
        return view
    }
    
    // MARK: createTableColm
    private func createTableColm() -> UIStackView {
        let stackView = createStackView(heightAnchorConstant: boardFrame.height, widthAnchorConstant: squreSize, axis: .vertical)
        
        for _ in 0..<numOfSqueresInCol {
            let tableCell = squreView()
            stackView.addArrangedSubview(tableCell)
        }
        
        return stackView
    }
    
    // MARK: createTable
    private func createTable() -> UIStackView {
        let mainStackView = createStackView(heightAnchorConstant: boardFrame.height, widthAnchorConstant: boardFrame.width, axis: .horizontal)
        
        for _ in 0..<numOfSqueresInRow {
            let colomStackView = createTableColm()
            mainStackView.addArrangedSubview(colomStackView)
        }
        
        return mainStackView
    }
    
    func stopGame() {
        foodSpownTimer?.invalidate()
        gameTimeTimer?.invalidate()
        snake.stopGame()
    }
    
    func resumeGame() {
        self.startSpowningFoodToBoard(timerHandler: { (timer) in
            self.foodSpownTimer = timer
        })
        RunLoop.current.add(self.foodSpownTimer!, forMode: .common)
       
        var i = time
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            i += 1
            self?.time = i
            self?.timePlayedInformer?(i)
        }
        
        gameTimeTimer = timer
        
        RunLoop.current.add(timer, forMode: .common)
        
        snake.resumeGame()
    }
    
    // MARK: Show Lost Popup
    
    private func showLostPopup() {
        
        gameTimeTimer?.invalidate()
        gameTimeTimer = nil
        foodSpownTimer?.invalidate()
        foodSpownTimer = nil
        
        let storyBoard: UIStoryboard = UIStoryboard(name: "SnakePopupViewController", bundle: nil)
        guard let lostPopup = storyBoard.instantiateViewController(withIdentifier: "SnakePopupViewController") as? SnakePopupViewController else { return }
        
        lostPopup.closeClousre = { [self] in
            startGame()
        }
        
        lostPopup.modalPresentationStyle = .overFullScreen
        
        lostPopup.count = count
        lostPopup.time = time
        let score = Int(CGFloat((1 + count) * time) * 1.2)
        lostPopup.score = score
        
        containerViewController?.show(lostPopup, sender: nil)
    }
    
    // MARK: Add Snake
    
    private func addSnakeToBoard() {
        let startLocation = CGPoint(x: (CGFloat(rowIndex) * squreSize) + 5, y: (CGFloat(colIndex) * squreSize) + 5)
        let size = squreSize - 10
        let speed = 0.78
        
        snake = Snake(startLocation: startLocation, size: size, speed:  speed)
        
        boardView.addSubview(snake.snakeHead!)
        
        snake.isFoodThere = { key in
            return self.spowndFoodDictinary[key]
        }
        
        snake.didEatFood = { [self] mul, key in
            self.foodSpownTimer?.invalidate()
            self.spowndFoodDictinary[key]?.assets.food.removeFromSuperview()
            self.spowndFoodDictinary[key] = nil
            self.spownTime *= mul
            
            self.spownTime = max(self.spownTime, 0.3)
            self.spownTime = min(self.spownTime, 1.6)
            
            self.count += 1
            
            self.foodCountComp?(count)
            
            self.startSpowningFoodToBoard(timerHandler: { (timer) in
                self.foodSpownTimer = timer
            })
            RunLoop.current.add(self.foodSpownTimer!, forMode: .common)
        }
        
        snake.addTail = { tail in
            self.boardView.addSubview(tail)
        }
        
        snake.didLose = {
            self.showLostPopup()
        }
        
        snake?.startMoving()
        
        startSpowningFoodToBoard(timerHandler: { [weak self] timer in
            self?.foodSpownTimer = timer
        })
    }
    
    private var spownTime = 1.6
    
    private func startSpowningFoodToBoard(timerHandler: @escaping (Timer) -> ()) {
        
        let timer = Timer(timeInterval: spownTime, repeats: true) { [self] (timer) in
            
            var foodTypeString = FoodType.regular.rawValue
            
            let spacialFoodChance = Double.random(in: 0...1)
            
            if spacialFoodChance <= 0.04 || spacialFoodChance >= 0.44 && spacialFoodChance < 0.5  || spacialFoodChance >= 0.95 {
                let isSlow =  Double.random(in: 0...1) > 0.25
                
                foodTypeString = isSlow ? FoodType.slow.rawValue : FoodType.doNoting.rawValue
            }
            
            
            let foodXindex = Int.random(in: 0...numOfSqueresInRow - 1)
            let foodYindex = Int.random(in: 0...numOfSqueresInCol - 1)
            
            let foodLoc = CGPoint(x: (CGFloat(foodXindex) * squreSize) + 5, y: (CGFloat(foodYindex) * squreSize) + 5)
            
            let imageName = {
                return foodTypeString
            }()
            
            let food = PointOnBoard.create(loc: foodLoc, size: (squreSize - 10), image: UIImage(named: imageName)!)
        
            let foodPoint = CGPoint(x: foodXindex, y: foodYindex)
            
            let foodPart = SnakePart(locationFrame: food.frame, image: food)
            
            let key = PointOnBoard.generateKeyPoint(origin: foodPoint)
           
            print("//////////////////////////////////////////////////////////////////////////////////\nfood: \(foodPart.description)\n")

            guard spowndFoodDictinary[key] == nil else {
                print("//////////////////////////////////////////////////////////////////////////////////\n Try to spown in (\(key)) but theres allredy food there \n")
                return
            }
          
            let headXindex: Int = Int(snake.snakeHead!.frame.origin.x / (snake.bodySize + 10))
            let headYindex: Int = Int((snake.snakeHead!.frame.origin.y / (snake.bodySize + 10))) + 1
            
            let headPoint = CGPoint(x: headXindex, y: headYindex)
            
            guard !foodPoint.equalTo(headPoint) else {
                print("//////////////////////////////////////////////////////////////////////////////////\n Try to spown in \(key) but head part (\(headPoint)) was there \n")
                return
            }
        
            guard !snake!.tuochBody(with: foodPart) else {
                print("//////////////////////////////////////////////////////////////////////////////////\n Try to spown in \(key) but body part (\(foodPart)) was there \n")
                return
            }
            
            let restrictedSpown = ((foodYindex == headYindex - 1 || foodYindex == headYindex - 2) && foodXindex == headXindex)
               || ((foodYindex == headYindex + 1 || foodYindex == headYindex + 2) || foodXindex == headXindex)
              && ((foodXindex == headXindex + 1 || foodXindex == headXindex + 2) || foodYindex == headYindex)
              && ((foodXindex == headXindex - 1 || foodXindex == headXindex - 2) || foodYindex == headYindex)
            
            guard !restrictedSpown else {
                print("//////////////////////////////////////////////////////////////////////////////////\n Try to spown in (\(key)) but is infront snake and allowed \n")
                return
            }
            
            boardView.addSubview(food)
            
            var egg: UIImageView? = nil
            
            if spownTime / Double(Int.random(in: 1...6)) <= 0.32 {
                egg = PointOnBoard.create(loc: food.frame.origin, size: food.frame.size.width, image: UIImage(named: "egg")!)
                
                boardView.addSubview(egg!)
            }
            
            spowndFoodDictinary[key] = (assets: (egg: egg, food: food), FoodType(rawValue: foodTypeString)!)
        }
        
        timerHandler(timer)
        
        RunLoop.current.add(timer, forMode: .common)
    }
}

class Snake {
    // dirction enum
    enum Dirction: Int {
        case up, down, left, right
    }
    
    private enum opration {
        case plus, minus
        
        func performOpration<T: Numeric>(a: T, b: T) -> T {
            switch self {
            case .plus:
                return a + b
            default:
                return a - b
            }
        }
    }
    
    static var head: SnakePart!
    var tail: SnakePart
    
    static var current: SnakePart?
    static var count: Int = 1
    static var index: Int = 0
    
    static var animate = true
    
    // MARK: Add food for snake to eat and graw by make movment faster
    
    var moveSpeed: Double!
    private var initalSpeed : Double!
    
    // snkae head parms
    var direction: Dirction = .left
    
    var snakeHead: UIImageView!

    var isFoodThere: ((String) -> (assets: (egg: UIImageView?, food: UIImageView), type: FoodType)?)?
    var didEatFood: ((Double, String) -> ())!
    var didLose: (() -> ())!
    var addTail: ((UIImageView) -> ())!
    
    private var movementTimer: Timer?
    
    var bodySize: CGFloat!

    init(startLocation: CGPoint, size: CGFloat, speed: Double) {
       
        let head = PointOnBoard.create(loc: startLocation, size: size, image: UIImage(named: "head")!)
        
        bodySize = size
        
        snakeHead = head
        
        moveSpeed = speed
        initalSpeed = speed
        
        let headPart = SnakePart(locationFrame: head.frame, image: head)
        
        Snake.head = headPart
        tail = headPart
        direction = Dirction(rawValue: Int.random(in: 0...3))!
        
        Snake.current = Snake.head
        Snake.count = 1
        Snake.index = 0
    }
    
    
    func stopGame() {
        movementTimer?.invalidate()
    }
    
    func resumeGame() {
        startMoving()
    }
    
    static func reset() {
        Snake.current = Snake.head
        Snake.index = 0
    }
    
    func startMoving() {
        let timer = startMovementTimer()
        
        movementTimer = timer
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    func move(to point: CGPoint, tail: @escaping (UIImageView?) -> ()) {
        
        UIView.animate(withDuration: Snake.animate ? moveSpeed * 0.08 : 0) {
            
            Snake.animate = true
            
            var part = Snake.head
            var frame = part!.image!.frame
            
            while let nextPart = self.getNetPart() {
                nextPart.locationFrame = frame
                
                let spin = abs(nextPart.image!.frame.origin.y - part!.image!.frame.origin.y) > abs(nextPart.image!.frame.origin.x - part!.image!.frame.origin.x)
                
                if spin && nextPart.image!.transform.isIdentity  {
                    nextPart.image!.transform = nextPart.image!.transform.rotated(by: CGFloat(Double.pi / 2))
                }
                else if !spin {
                    nextPart.image!.transform = .identity
                }
                
                nextPart.image!.image = UIImage(named: "bodyPart")
                
                nextPart.image!.layer.cornerRadius = nextPart.image!.frame.width / 2
                part!.image!.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner, .layerMaxXMinYCorner]
                
                part = nextPart
                frame = part!.image!.frame
                part!.image?.frame = part!.locationFrame
            }
            
            tail(part!.image!)
            
            Snake.reset()
            
            Snake.head!.image!.frame.origin.x = point.x
            Snake.head!.image!.frame.origin.y = point.y
            
            if Snake.count > 1 {
                part!.image!.layer.cornerRadius = part!.image!.frame.width / 1.4
            }
        }
    }
    
    private func startMovementTimer() -> Timer {
        
        return Timer(timeInterval: moveSpeed, repeats: true) { [self] (timer) in
            printBody()
            
            let moveCalc : (_ num: CGFloat, _ op: opration) -> (CGFloat) = { (number: CGFloat, op: opration) in
                return op.performOpration(a: number, b: self.bodySize + 10.0)
            }
            
            var moveIterval: CGFloat = 0
            
            var isInBoard = true
            
            let snakeHead = Snake.head?.image
            
            switch direction {
            case .right:
                moveIterval = moveCalc(snakeHead!.frame.origin.x, .plus)
                isInBoard = Int(moveIterval) < Int(snakeHead!.superview!.frame.origin.x + snakeHead!.superview!.frame.width) - Int(snakeHead!.frame.width)
            case .left:
                moveIterval = moveCalc(snakeHead!.frame.origin.x, .minus)
                isInBoard = Int(moveIterval) > 0
            case .up:
                moveIterval = moveCalc(snakeHead!.frame.origin.y, .minus)
                isInBoard = Int(moveIterval) > 0
            case .down:
                moveIterval = moveCalc(snakeHead!.frame.origin.y, .plus)
                isInBoard = Int(moveIterval) < Int(snakeHead!.superview!.frame.origin.y + snakeHead!.superview!.frame.height) - Int(3 * snakeHead!.frame.height) - Int(bodySize / 2)
            }
            
            guard isInBoard else {
                timer.invalidate()
                didLose()
                return
            }
            
            var movePoint: CGPoint = .zero
            switch direction {
            case  .left, .right:
                movePoint = CGPoint(x: moveIterval, y:  snakeHead!.frame.origin.y)
            case .up, .down:
                movePoint = CGPoint(x: snakeHead!.frame.origin.x , y:  moveIterval)
            }
            
            guard !tuochBody(with: Snake.head) else {
                timer.invalidate()
                didLose()
                return
            }
    
            move(to: movePoint) { (tail) in
                addTail(tail!)
            }
            
            let xFloat: CGFloat = (snakeHead!.frame.origin.x - 5) / (bodySize + 10.0)
            let yFloat: CGFloat = (snakeHead!.frame.origin.y - 5) / (bodySize + 10.0)
            
            let x = xFloat.truncatingRemainder(dividingBy: 1) > 0.5 ? Int(xFloat + 1) : Int(xFloat)
            let y = Int(yFloat)
            
            let point = CGPoint(x: x, y: y)
            
            let key = PointOnBoard.generateKeyPoint(origin: point)
            
            if let asstet = isFoodThere!(key) {
                guard asstet.assets.egg == nil else {
                    movementTimer?.invalidate()
                    didLose()
                    return
                }
                eatFood(key: key ,food: asstet.assets.food, type: asstet.type)
            }
        }
    }
    
    private var allow = true
    
    func fire(bulletHandler: @escaping (UIImageView) -> (), borderHendaler:  @escaping (UIImageView, Timer) -> (Bool), fireBlocked: @escaping (UIImageView) -> ()) {
        let bullet = PointOnBoard.create(loc: snakeHead.frame.origin, size: bodySize, image: UIImage(named: "fireBall")!)
        
        guard allow else { return }
        
        allow = false
        
        bullet.alpha = 0
        
        bulletHandler(bullet)
        
        let fireDirection = direction
        
        let timer = Timer(timeInterval: moveSpeed / 10, repeats: true) { [self] (timer) in
            switch fireDirection {
            case .right:
                bullet.frame.origin.x += bodySize
            case .left:
                bullet.frame.origin.x -= bodySize
            case .down:
                bullet.frame.origin.y += bodySize
            case .up:
                bullet.frame.origin.y -= bodySize
            }
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.05) {
                bullet.alpha = 1
            }
            
            let part = SnakePart(locationFrame: bullet.frame, image: bullet)
            
            if tuochBody(with: part) {
                timer.invalidate()
                fireBlocked(bullet)
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.08) {
                    allow = true
                }
            }
            
            let finish = borderHendaler(bullet, timer)
            
            if finish {
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                    allow = true
                }
            }
        }
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    func eatFood(key: String, food: UIImageView, type: FoodType) {
        
        movementTimer?.invalidate()
        
        let part = PointOnBoard.create(loc: tail.locationFrame.origin, size: bodySize)
        
        switch type {
        case .regular, .slow:
           eat(imageView: part)
        default:
            break
        }
        
        var foodTuple: (mul: Double, key: String)

        switch type  {
        case .regular:
            moveSpeed *= 0.96
            foodTuple.mul = 0.98
            foodTuple.key = key
            
        case .slow:
            moveSpeed *= 1.05
            foodTuple.mul = 1.02
            foodTuple.key = key
            
        default:
            foodTuple.mul = 1
            foodTuple.key = key
            break
        }
        
        moveSpeed = max(moveSpeed, 0.2)
        moveSpeed = min(moveSpeed, initalSpeed)
        
        didEatFood(foodTuple.mul, foodTuple.key)
        
        movementTimer = startMovementTimer()
        
        RunLoop.current.add(movementTimer!, forMode: .common)
    }
    
    func eat(imageView: UIImageView) {
        let part = SnakePart(locationFrame: tail.locationFrame, image: imageView)
        
        tail.addBodyPart(part: part)
        
        print("//////////////////////////////////////////////////////////////////////////////////\neat food at: \(part.printPart())\n")
        
        tail = part
        
        Snake.current = Snake.head
        Snake.count += 1
        Snake.animate = Snake.count != 2
    }
    
    func tuochBody(with part: SnakePart) -> Bool {
        Snake.reset()
        
        while let nextPart = getNetPart() {
            if nextPart.image!.frame.contains(part.image!.center) {
                return true
            }
        }
        
        Snake.reset()
        
        return false
    }
    
    private func isInfront(frame: CGRect) -> Bool {
        
        let size = (bodySize + 10)
        
        let yIndex = snakeHead.frame.origin.y / size
        let xIndex = snakeHead.frame.origin.x / size
        
        switch direction {
        case .up:
            return yIndex == frame.origin.y - size && xIndex == frame.origin.x
        case .down:
            return yIndex == frame.origin.y + size && xIndex == frame.origin.x
        case .left:
            return xIndex == frame.origin.x - size && yIndex == frame.origin.y
        case .right:
            return  xIndex == frame.origin.x + size && yIndex == frame.origin.y
        }
    }
    
    func printBody() {
        Snake.reset()
        
        let head = "Head { \(Snake.head!.printPart()) index: \(Snake.index) of count: \(Snake.count - 1) }"
        let body = "Body {@text}"
        
        var text = ""
        
        while let part = getNetPart() {
            text += ", \(part.printPart()) index: \(Snake.index) of count: \(Snake.count - 1) "
        }
        
        text = "//////////////////////////////////////////////////////////////////////////////////\n\(text.isEmpty ? head : "\(head) \(body.replacingOccurrences(of: "@text", with: text.dropFirst()))")\n"
        
        print(text)
        
        Snake.reset()
    }
    
    func getNetPart() -> SnakePart? {
        Snake.current = Snake.current?.prv
        Snake.index += 1
        
        return Snake.current
    }
}

internal class SnakePart: CustomStringConvertible {
    
    var locationFrame: CGRect
    var image: UIImageView?
    
    var prv: SnakePart?
    var next: SnakePart?

    var description: String {
        return printPart()
    }
    
    init(locationFrame: CGRect, image: UIImageView?) {
        self.locationFrame = locationFrame
        self.image = image
    }
    
    func updateFrame(frame: CGRect) {
        locationFrame = frame
    }
    
    func addBodyPart(part: SnakePart) {
        prv = part
        part.next = self
    }
    
    func printPart() -> String {
        let xFloat: CGFloat = (image!.frame.origin.x / image!.frame.size.width) + 1
        let yFloat: CGFloat = (image!.frame.origin.y  / image!.frame.size.height)
        
        let point = CGPoint(x: xFloat, y: yFloat)
        
        let originX = Int(point.x)
        let originY = Int(point.y)
        
        let key = "(\(originX), \(originY))"
        
        return "\(key)"
    }
}

class PointOnBoard {
    static func create(loc: CGPoint, size: CGFloat, image: UIImage = UIImage(named: "bodyPart")!) -> UIImageView {
        let bodyFrame = CGRect(x: loc.x, y: loc.y, width: size, height: size)
        
        let bodyImageView = UIImageView(frame: bodyFrame)
        
        let bodyImage = image
        
        bodyImageView.image = bodyImage
        
        bodyImageView.layer.cornerRadius = bodyImageView.frame.width / 2
        
        bodyImageView.clipsToBounds = true
        
        return bodyImageView
    }
    
    static func generateKeyPoint(origin: CGPoint) -> String {
        let originX = Int(origin.x)
        let originY = Int(origin.y)
        
        let key = "(\(originX), \(originY))"
        
        return key
    }
}
