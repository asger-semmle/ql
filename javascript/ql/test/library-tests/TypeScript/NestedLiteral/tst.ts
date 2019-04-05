interface T {
  name: string;
  children?: T[];
}

let x: T = {
  name: 'x',
  children: [
    { name: 'x1' },
    {
      name: 'x2',
      children: [
        { name: 'x3' }
      ]
    }
  ]
}
