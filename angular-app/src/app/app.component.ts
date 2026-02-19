import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  title = 'Hello World Angular';
  version = '1.0.0';
  environment = 'EKS Production';
  buildDate = new Date().toLocaleDateString('fr-FR');
  status = 'RUNNING';
}