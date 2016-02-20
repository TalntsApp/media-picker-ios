//
//  ViewController.m
//  Example
//
//  Created by Mikhail Stepkin on 18.02.16.
//  Copyright © 2016 Ramotion. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  [self.childViewControllers
      enumerateObjectsUsingBlock:^(__kindof UIViewController* _Nonnull obj,
                                   NSUInteger idx, BOOL* _Nonnull stop) {
        [obj viewDidLayoutSubviews];
      }];
}

@end
